#pragma once

#include <QDateTime>
#include <QObject>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>

/// @brief Persisted mission scheduler for the Y-GCS Plan view.
///
/// Schedules keep a snapshot of the plan on disk (`.plan` file) and raise
/// `due(entry)` when an occurrence arrives. The Plan view loads the snapshot,
/// uploads it through the normal mission pipeline, then starts the mission.
class YGCSScheduler : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList schedules READ schedules NOTIFY schedulesChanged)

public:
    explicit YGCSScheduler(QObject *parent = nullptr);

    QVariantList schedules() const { return _schedules; }

    Q_INVOKABLE void add(const QVariantMap &entry);
    Q_INVOKABLE void remove(const QString &id);
    Q_INVOKABLE void setEnabled(const QString &id, bool enabled);
    Q_INVOKABLE void complete(const QString &id);
    Q_INVOKABLE void fail(const QString &id, const QString &reason);
    Q_INVOKABLE void markWaiting(const QString &id);
    Q_INVOKABLE void retryWaiting();
    Q_INVOKABLE void checkDue();

    Q_INVOKABLE QString todayString() const;
    Q_INVOKABLE QString newSchedulePath(const QString &id) const;
    Q_INVOKABLE QString countdownText(const QVariantMap &entry) const;
    Q_INVOKABLE QString repeatText(const QVariantMap &entry) const;

signals:
    void schedulesChanged();
    void due(const QVariantMap &entry);

private:
    static QDateTime parseLocal(const QString &text);
    static QString formatLocal(const QDateTime &dt);
    QDateTime nextOccurrence(const QVariantMap &entry, qint64 fromMs) const;
    void persist();
    void load();
    int indexOf(const QString &id) const;

    QVariantList _schedules;
    QTimer _timer;
};
