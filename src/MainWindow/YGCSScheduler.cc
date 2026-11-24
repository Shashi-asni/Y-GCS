#include "YGCSScheduler.h"

#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSettings>
#include <QStandardPaths>

#include <utility>

static constexpr const char *kSettingsKey = "ygcs/schedules";

YGCSScheduler::YGCSScheduler(QObject *parent)
    : QObject(parent)
{
    load();
    _timer.setInterval(5000);
    connect(&_timer, &QTimer::timeout, this, &YGCSScheduler::checkDue);
    _timer.start();
}

void YGCSScheduler::load()
{
    QSettings settings;
    const QByteArray raw = settings.value(QLatin1String(kSettingsKey)).toByteArray();
    if (raw.isEmpty()) {
        return;
    }
    const QJsonDocument doc = QJsonDocument::fromJson(raw);
    const QJsonArray array = doc.array();
    for (const QJsonValue &value : array) {
        _schedules.append(value.toObject().toVariantMap());
    }
}

void YGCSScheduler::persist()
{
    QJsonArray array;
    for (const QVariant &value : std::as_const(_schedules)) {
        array.append(QJsonObject::fromVariantMap(value.toMap()));
    }
    QSettings settings;
    settings.setValue(QLatin1String(kSettingsKey), QJsonDocument(array).toJson(QJsonDocument::Compact));
}

int YGCSScheduler::indexOf(const QString &id) const
{
    for (int i = 0; i < _schedules.count(); i++) {
        if (_schedules.at(i).toMap().value(QStringLiteral("id")).toString() == id) {
            return i;
        }
    }
    return -1;
}

QDateTime YGCSScheduler::parseLocal(const QString &text)
{
    if (text.isEmpty()) {
        return QDateTime();
    }
    QDateTime dt = QDateTime::fromString(text, Qt::ISODate);
    if (!dt.isValid()) {
        dt = QDateTime::fromString(text, QStringLiteral("yyyy-MM-ddTHH:mm:ss"));
    }
    return dt;
}

QString YGCSScheduler::formatLocal(const QDateTime &dt)
{
    return dt.toString(QStringLiteral("yyyy-MM-ddTHH:mm:ss"));
}

QDateTime YGCSScheduler::nextOccurrence(const QVariantMap &entry, qint64 fromMs) const
{
    const QDateTime start = parseLocal(entry.value(QStringLiteral("startDateTime")).toString());
    if (!start.isValid()) {
        return QDateTime();
    }

    QDateTime now = QDateTime::fromMSecsSinceEpoch(fromMs);
    QDateTime end = parseLocal(entry.value(QStringLiteral("endDateTime")).toString());
    if (end.isValid()) {
        end.setTime(QTime(23, 59, 59, 999));
    }

    const QString repeat = entry.value(QStringLiteral("repeat"), QStringLiteral("once")).toString();
    const QTime timeOfDay = start.time();

    if (repeat == QLatin1String("once")) {
        return start;
    }

    if (repeat == QLatin1String("daily")) {
        QDateTime candidate(now.date(), timeOfDay);
        while (candidate < now) {
            candidate = candidate.addDays(1);
        }
        if (end.isValid() && candidate > end) {
            return QDateTime();
        }
        return candidate;
    }

    if (repeat == QLatin1String("weekly")) {
        const QVariantList days = entry.value(QStringLiteral("weeklyDays")).toList();
        if (days.isEmpty()) {
            return QDateTime();
        }
        QDateTime candidate(now.date(), timeOfDay);
        for (int i = 0; i < 21; i++) {
            const int jsDay = candidate.date().dayOfWeek() % 7;
            bool selected = false;
            for (const QVariant &day : days) {
                if (day.toInt() == jsDay) {
                    selected = true;
                    break;
                }
            }
            if (candidate >= now && selected) {
                if (!end.isValid() || candidate <= end) {
                    return candidate;
                }
            }
            candidate = candidate.addDays(1);
            candidate.setTime(timeOfDay);
        }
        return QDateTime();
    }

    if (repeat == QLatin1String("custom")) {
        const QVariantList dates = entry.value(QStringLiteral("customDates")).toList();
        QDateTime best;
        for (const QVariant &value : dates) {
            const QString text = value.toString();
            const QDateTime candidate = parseLocal(text + QStringLiteral("T") + timeOfDay.toString(QStringLiteral("HH:mm")) + QStringLiteral(":00"));
            if (!candidate.isValid() || candidate < now) {
                continue;
            }
            if (end.isValid() && candidate > end) {
                continue;
            }
            if (!best.isValid() || candidate < best) {
                best = candidate;
            }
        }
        return best;
    }

    return QDateTime();
}

void YGCSScheduler::add(const QVariantMap &entry)
{
    QVariantMap stored = entry;
    if (!stored.contains(QStringLiteral("status"))) {
        stored[QStringLiteral("status")] = QStringLiteral("scheduled");
    }
    if (!stored.contains(QStringLiteral("enabled"))) {
        stored[QStringLiteral("enabled")] = true;
    }
    stored[QStringLiteral("lastPromptedOccurrence")] = QString();
    _schedules.append(stored);
    persist();
    emit schedulesChanged();
}

void YGCSScheduler::remove(const QString &id)
{
    const int index = indexOf(id);
    if (index < 0) {
        return;
    }
    const QString planFile = _schedules.at(index).toMap().value(QStringLiteral("planFile")).toString();
    if (!planFile.isEmpty()) {
        QFile::remove(planFile);
    }
    _schedules.removeAt(index);
    persist();
    emit schedulesChanged();
}

void YGCSScheduler::setEnabled(const QString &id, bool enabled)
{
    const int index = indexOf(id);
    if (index < 0) {
        return;
    }
    QVariantMap entry = _schedules.at(index).toMap();
    entry[QStringLiteral("enabled")] = enabled;
    entry[QStringLiteral("status")] = enabled ? QStringLiteral("scheduled") : QStringLiteral("cancelled");
    entry[QStringLiteral("lastPromptedOccurrence")] = QString();
    _schedules[index] = entry;
    persist();
    emit schedulesChanged();
}

void YGCSScheduler::complete(const QString &id)
{
    const int index = indexOf(id);
    if (index < 0) {
        return;
    }
    QVariantMap entry = _schedules.at(index).toMap();
    entry[QStringLiteral("lastStartedAt")] = QDateTime::currentDateTimeUtc().toString(Qt::ISODate);
    entry[QStringLiteral("lastError")] = QString();
    if (entry.value(QStringLiteral("repeat"), QStringLiteral("once")).toString() == QLatin1String("once")) {
        entry[QStringLiteral("status")] = QStringLiteral("completed");
        entry[QStringLiteral("enabled")] = false;
    } else {
        entry[QStringLiteral("status")] = QStringLiteral("scheduled");
        entry[QStringLiteral("lastPromptedOccurrence")] = QString();
    }
    _schedules[index] = entry;
    persist();
    emit schedulesChanged();
}

void YGCSScheduler::fail(const QString &id, const QString &reason)
{
    const int index = indexOf(id);
    if (index < 0) {
        return;
    }
    QVariantMap entry = _schedules.at(index).toMap();
    entry[QStringLiteral("status")] = QStringLiteral("failed");
    entry[QStringLiteral("lastError")] = reason;
    _schedules[index] = entry;
    persist();
    emit schedulesChanged();
}

void YGCSScheduler::markWaiting(const QString &id)
{
    const int index = indexOf(id);
    if (index < 0) {
        return;
    }
    QVariantMap entry = _schedules.at(index).toMap();
    entry[QStringLiteral("status")] = QStringLiteral("waiting");
    _schedules[index] = entry;
    persist();
    emit schedulesChanged();
}

void YGCSScheduler::retryWaiting()
{
    bool changed = false;
    for (int i = 0; i < _schedules.count(); i++) {
        QVariantMap entry = _schedules.at(i).toMap();
        if (entry.value(QStringLiteral("status")).toString() == QLatin1String("waiting")) {
            entry[QStringLiteral("lastPromptedOccurrence")] = QString();
            _schedules[i] = entry;
            changed = true;
        }
    }
    if (changed) {
        persist();
        emit schedulesChanged();
        checkDue();
    }
}

void YGCSScheduler::checkDue()
{
    const qint64 now = QDateTime::currentDateTime().toMSecsSinceEpoch();
    for (int i = 0; i < _schedules.count(); i++) {
        QVariantMap entry = _schedules.at(i).toMap();
        if (!entry.value(QStringLiteral("enabled"), true).toBool()) {
            continue;
        }
        const QString status = entry.value(QStringLiteral("status")).toString();
        if (status == QLatin1String("completed") || status == QLatin1String("cancelled")) {
            continue;
        }
        const QDateTime next = nextOccurrence(entry, now - 90000);
        if (!next.isValid() || next.toMSecsSinceEpoch() > now) {
            continue;
        }
        const QString occurrence = formatLocal(next);
        if (entry.value(QStringLiteral("lastPromptedOccurrence")).toString() == occurrence) {
            continue;
        }
        entry[QStringLiteral("lastPromptedOccurrence")] = occurrence;
        entry[QStringLiteral("status")] = QStringLiteral("waiting");
        _schedules[i] = entry;
        persist();
        emit schedulesChanged();
        emit due(entry);
        return;
    }
}

QString YGCSScheduler::todayString() const
{
    return QDate::currentDate().toString(QStringLiteral("yyyy-MM-dd"));
}

QString YGCSScheduler::newSchedulePath(const QString &id) const
{
    QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (dir.isEmpty()) {
        dir = QDir::homePath() + QStringLiteral("/.y-gcs");
    }
    dir += QStringLiteral("/schedules");
    QDir().mkpath(dir);
    return dir + QStringLiteral("/") + id + QStringLiteral(".plan");
}

QString YGCSScheduler::countdownText(const QVariantMap &entry) const
{
    const QString status = entry.value(QStringLiteral("status")).toString();
    if (status == QLatin1String("completed")) {
        return tr("Completed");
    }
    if (status == QLatin1String("failed")) {
        return tr("Failed");
    }
    const QDateTime next = nextOccurrence(entry, QDateTime::currentDateTime().toMSecsSinceEpoch());
    if (!next.isValid()) {
        return tr("No upcoming run");
    }
    const qint64 diff = next.toMSecsSinceEpoch() - QDateTime::currentDateTime().toMSecsSinceEpoch();
    if (diff <= 0) {
        return tr("Due now");
    }
    const qint64 total = diff / 1000;
    const qint64 days = total / 86400;
    const qint64 hours = (total % 86400) / 3600;
    const qint64 mins = (total % 3600) / 60;
    if (days > 0) {
        return QStringLiteral("%1d %2h").arg(days).arg(hours);
    }
    if (hours > 0) {
        return QStringLiteral("%1h %2m").arg(hours).arg(mins);
    }
    return QStringLiteral("%1m").arg(mins);
}

QString YGCSScheduler::repeatText(const QVariantMap &entry) const
{
    const QString repeat = entry.value(QStringLiteral("repeat"), QStringLiteral("once")).toString();
    if (repeat == QLatin1String("daily")) {
        return tr("Every day");
    }
    if (repeat == QLatin1String("weekly")) {
        return tr("Every week");
    }
    if (repeat == QLatin1String("custom")) {
        return tr("Custom dates");
    }
    return tr("Once");
}
