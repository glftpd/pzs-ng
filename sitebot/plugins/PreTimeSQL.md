# PreTimeSQL Plugin for pzs-ng

**Author:** [ZarTek-Creole](https://github.com/ZarTek-Creole)  
**Version:** 1.0.0

---

## 1. Overview

`PreTimeSQL` is a plugin for the `pzs-ng` Eggdrop bot framework. Its purpose is to announce the "pre time" of a release when a new directory (`NEWDIR`) is created on the site. It replaces the standard `NEWDIR` announcement with a custom one that includes the age of the release.

This plugin is designed to be robust, flexible, and efficient, leveraging the `MySQLManager` plugin for centralized database connection management.

## 2. Features

- **Centralized Connection Management:** Uses `MySQLManager` to handle all database interactions, avoiding connection redundancy.
- **Automatic Table Creation:** The required database table is created automatically on the first run.
- **Flexible Configuration:** Table and column names are configurable, allowing easy integration with existing database schemas.
- **Themable Announcements:** All user-facing messages can be customized via a separate theme file (`PreTimeSQL.zpt`).
- **"Old Pre" Detection:** Announces releases differently if they are older than a configurable threshold.
- **Directory Exclusion:** Easily ignore certain directories (like `subs`, `sample`, etc.).

## 3. Requirements

- **pzs-ng:** The core bot framework.
- **MySQLManager Plugin:** This plugin is required for `PreTimeSQL` to function. It must be loaded *before* `PreTimeSQL`.
- **TclOO (Tcl 8.6+):** Required by the `MySQLManager`'s Query Builder.

## 4. Installation

1.  **Place Files:** Copy `PreTimeSQL.tcl` and `PreTimeSQL.zpt` into your `scripts/pzs-ng/plugins/` directory.
2.  **Edit `eggdrop.conf`:** Add the following lines to your Eggdrop config file. Ensure `MySQLManager.tcl` is sourced *before* `PreTimeSQL.tcl`.
    ```tcl
    #--> Database connection manager
    source pzs-ng/plugins/MySQLManager.tcl

    #--> Pre-time announcer
    source pzs-ng/plugins/PreTimeSQL.tcl
    ```
3.  **Rehash:** Rehash your Eggdrop bot for the changes to take effect.

## 5. Configuration

Configuration is split between three files: `MySQLManager.tcl`, `PreTimeSQL.tcl`, and `PreTimeSQL.zpt`.

### 5.1. MySQLManager Setup

First, you must define a database connection in `MySQLManager.tcl`. `PreTimeSQL` will use this connection. By default, it looks for a connection named `"pre_db"`.

**Example `MySQLManager.tcl` configuration:**
```tcl
# ... inside MySQLManager.tcl ...
variable connections {
    # Connection for PreTimeSQL
    pre_db {
        host     "127.0.0.1"
        port     3306
        user     "pre_user"
        pass     "pre_password"
        db       "pre_database"
    }
    # ... other connections ...
}
# ...
```

### 5.2. PreTimeSQL.tcl Setup

Next, configure the variables at the top of the `PreTimeSQL.tcl` file:

- `conn_name`: The name of the connection to use from `MySQLManager.tcl`. Defaults to `"pre_db"`.
- `table_name`: The name of the database table to use. Defaults to `"pre_times"`.
- `col_release_name`: The name of the column storing the release name. Defaults to `"release_name"`.
- `col_pre_timestamp`: The name of the column storing the pre time (as a Unix timestamp). Defaults to `"pre_timestamp"`.
- `lateMins`: The number of minutes after which a release is considered "old". Defaults to `10`.
- `ignoreDirs`: A list of directory names (using glob patterns) to exclude from pre time lookups.

## 6. The Database

### 6.1. Automatic Table Creation

The plugin will attempt to create the necessary table if it does not exist. The default schema is:
```sql
CREATE TABLE IF NOT EXISTS `pre_times` (
    `release_name` VARCHAR(255) NOT NULL,
    `pre_timestamp` INT(11) UNSIGNED NOT NULL,
    PRIMARY KEY (`release_name`),
    INDEX `idx_pre_timestamp` (`pre_timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```
You can customize the table and column names in the configuration section.

### 6.2. Populating the Database

**Important:** This plugin *reads* from the database; it does not write pre times to it. You must have another script or process responsible for populating the pre time table.

For example, a pre-bot, a site script, or a manual process should insert a new row for each release, containing the release name and the Unix timestamp of its pre time.

## 7. Theme Customization (`PreTimeSQL.zpt`)

You can customize the announcement messages in `PreTimeSQL.zpt`.

### Available Variables:
- `%pf`: Path/Filename of the release.
- `%u_name`: Uploader's name.
- `%g_name`: Uploader's primary group.
- `%u_tagline`: Uploader's tagline.
- `%preage`: Formatted duration since the pre (e.g., "5m 12s").
- `%predate`: Date of the pre (e.g., "01/01/24").
- `%pretime`: Time of the pre (e.g., "15:04:55").

### Example Themes:
```tcl
# Default for new pre's
set theme(NEWPRETIME) "NEW PRE » \[%g_name] got '%pf' (pre: %preage ago)"

# Default for old pre's
set theme(OLDPRETIME) "OLD PRE » \[%g_name] got '%pf' (pre: %preage ago on %predate)"

``` 