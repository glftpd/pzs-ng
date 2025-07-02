# pzs-ng PreTimeSQL Plugin

**Author:** [ZarTek-Creole](https://github.com/ZarTek-Creole)  
**Repo:**   [https://github.com/ZarTek-Creole/pzs-PreTimeSQL](https://github.com/ZarTek-Creole/pzs-PreTimeSQL)  
**Version:** 2.0.0

---

## 1. Overview

`PreTimeSQL` is a powerful and flexible plugin for the `pzs-ng` Eggdrop bot framework. It replaces the standard `NEWDIR` announcement with a detailed, configurable message that includes the release's "pre" time.

It uses the `MySQLManager` plugin to interact with a database, allowing it to not only announce pre times but also to automatically log releases, update existing records, and store a wealth of optional data for archival and analysis purposes.

## 2. Features

- **Centralized Connection Management:** Uses `MySQLManager` for robust and efficient database handling.
- **Automatic Table Creation & Indexing:** Automatically creates a fully-indexed database table on the first run.
- **Auto-Add New Releases:** If a release is announced via `NEWDIR` but isn't in the database, the plugin can add it automatically with the current time as its pre time.
- **Auto-Update Null Timestamps:** If a release exists in the database but its `pre_timestamp` is `NULL`, the plugin can update it upon a `NEWDIR` event.
- **Rich Data Storage:** Optionally stores detailed information for each release:
  - Site section
  - Sitename
  - Uploader's nickname and primary group
  - The triggering event (`NEWDIR`)
  - The release group name (extracted from the release string)
- **Highly Configurable:** Nearly every aspect can be toggled or customized via variables at the top of the script file.
- **Themable Announcements:** All announcements are fully customizable through the `PreTimeSQL.zpt` theme file, with access to a wide range of variables.
- **Directory Exclusion:** A configurable list to ignore announcements for specific directories (e.g., `sample`, `subs`).

## 3. Requirements

- **pzs-ng:** The core bot framework.
- **MySQLManager Plugin:** This plugin is **required** for `PreTimeSQL` to function. It must be loaded *before* `PreTimeSQL` in your configuration.
- **TclOO (Tcl 8.6+):** Required by the `MySQLManager`'s Query Builder.

## 4. Installation

1. **Place Files:** Copy `PreTimeSQL.tcl` and `PreTimeSQL.zpt` into your `scripts/pzs-ng/plugins/` directory.
2. **Edit `eggdrop.conf`:** Add the following lines to your Eggdrop config file. It is critical that `MySQLManager.tcl` is sourced **before** `PreTimeSQL.tcl`.

    ```tcl
    #--> Database connection manager
    source pzs-ng/plugins/MySQLManager.tcl

    #--> Pre-time announcer
    source pzs-ng/plugins/PreTimeSQL.tcl
    ```

3. **Configure:** Edit the configuration variables at the top of `PreTimeSQL.tcl` to suit your needs (see section 5 below).
4. **Rehash:** Rehash your Eggdrop bot. The plugin will automatically create the database table if it doesn't exist.

## 5. Configuration (`PreTimeSQL.tcl`)

All configuration is done by editing the `variable` definitions at the top of `PreTimeSQL.tcl`.

| Variable                  | Description                                                                                                   | Default Value      |
| ------------------------- | ------------------------------------------------------------------------------------------------------------- | ------------------ |
| `conn_name`               | The name of the connection to use from `MySQLManager.tcl`.                                                    | `"default"`        |
| `table_name`              | The name of the database table to use.                                                                        | `"pre_times"`      |
| `lateMins`                | Number of minutes after which a pre is considered "old" and uses the `OLDPRETIME` theme.                        | `10`               |
| `ignoreDirs`              | A Tcl list of glob patterns for directories to ignore.                                                        | `{cd[0-9] ...}`    |
| `add_missing_releases`    | If `1`, automatically adds releases to the DB if they aren't found.                                           | `1`                |
| `update_null_timestamp`   | If `1`, updates a release's timestamp if it is found in the DB but the timestamp is `NULL`.                   | `1`                |
| `col_id`                  | Column name for the primary auto-incrementing ID.                                                             | `"id"`             |
| `col_release_name`        | Column name for the release name.                                                                             | `"release_name"`   |
| `col_pre_timestamp`       | Column name for the Unix timestamp of the pre.                                                                | `"pre_timestamp"`  |
| `col_section_name`        | **Optional:** Column for the site section. Leave empty (`""`) to disable.                                     | `"section"`        |
| `col_sitename`            | **Optional:** Column for the sitename. Leave empty (`""`) to disable.                                         | `"sitename"`       |
| `col_uploader_nick`       | **Optional:** Column for the uploader's nick. Leave empty (`""`) to disable.                                  | `"uploader_nick"`  |
| `col_uploader_group`      | **Optional:** Column for the uploader's group. Leave empty (`""`) to disable.                                 | `"uploader_group"` |
| `col_event_name`          | **Optional:** Column for the event name (e.g., `NEWDIR`). Leave empty (`""`) to disable.                        | `"event"`          |
| `col_group_name`          | **Optional:** Column for the release group (extracted from rlsname). Leave empty (`""`) to disable.           | `"group_name"`     |

## 6. The Database

The plugin handles its own database schema. If you ever change the column configuration, you must **drop the existing table** so the plugin can recreate it with the new structure on the next rehash.

### 6.1. Final Schema

```sql
CREATE TABLE IF NOT EXISTS `pre_times` (
  `id` INT(11) UNSIGNED AUTO_INCREMENT NOT NULL,
  `release_name` VARCHAR(255) NOT NULL,
  `pre_timestamp` INT(11) UNSIGNED DEFAULT NULL,
  `section` VARCHAR(255) DEFAULT NULL,
  `sitename` VARCHAR(255) DEFAULT NULL,
  `uploader_nick` VARCHAR(255) DEFAULT NULL,
  `uploader_group` VARCHAR(255) DEFAULT NULL,
  `event` VARCHAR(50) DEFAULT NULL,
  `group_name` VARCHAR(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_release_name` (`release_name`),
  INDEX `idx_pre_timestamp` (`pre_timestamp`),
  INDEX `idx_section` (`section`),
  INDEX `idx_sitename` (`sitename`),
  INDEX `idx_uploader_nick` (`uploader_nick`),
  INDEX `idx_uploader_group` (`uploader_group`),
  INDEX `idx_event` (`event`),
  INDEX `idx_group_name` (`group_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

## 7. Theme Customization (`PreTimeSQL.zpt`)

You can customize the announcement messages in `PreTimeSQL.zpt`. For a full list of available variables and formatting options, please see the comments at the top of the `PreTimeSQL.zpt` file itself.

### Example Themes

```tcl
# Announce for a recent pre (within the 'lateMins' threshold).
announce.NEWPRETIME = "[%b{NEW PRE}] [%section] %b{%relname} uploaded by %b{%u_name} (%g_name) %b{%size} @ %b{%speed} (Pre was %preage ago)"

# Announce for an old pre (older than the 'lateMins' threshold).
announce.OLDPRETIME = "[%b{OLD PRE}] [%section] %b{%relname} uploaded by %b{%u_name} (%g_name) (Pre was %preage ago on %predate)"
```
