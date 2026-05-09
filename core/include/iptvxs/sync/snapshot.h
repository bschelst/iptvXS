// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#pragma once

#include <QByteArray>
#include <QSqlDatabase>
#include <QString>

#include "iptvxs/security/credential_vault.h"

namespace iptvxs {

struct SnapshotMergeStats {
    int favoritesPulled{0};
    int historyPulled{0};
    int channelGroupsPulled{0};
    int groupMembersPulled{0};
    int serversPulled{0};
    int tombstonesApplied{0};
};

// Serialize the syncable subset of the database (favorites, history,
// channel_groups, group_members, servers + sync_state) into a JSON document
// keyed by external identifiers (server name, channel external_id) so it
// stays portable across devices that have different local row ids.
//
// Server credentials (url, username, password) are encrypted via
// CredentialVault before serialization — the resulting JSON contains no
// plaintext passwords.
QByteArray exportSnapshot(QSqlDatabase &db, CredentialVault *vault,
                          const QString &deviceUuid);

// Apply a remote snapshot to the local database using last-write-wins
// per row. Returns counts of what was pulled / tombstoned.
//
// Matching keys (per table):
//   favorites      → (server_name, channel_external_id)
//   history        → (server_name, channel_external_id) — single live row
//                    per channel; older rows tombstoned implicitly via LWW
//   servers        → name
//   channel_groups → name
//   group_members  → (group_name, server_name, channel_external_id)
SnapshotMergeStats importSnapshot(QSqlDatabase &db, CredentialVault *vault,
                                  const QByteArray &json);

} // namespace iptvxs
