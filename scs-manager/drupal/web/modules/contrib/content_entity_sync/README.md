# Content Entity Sync (YAML)

Drupal Content Entity Sync module provides Drush commands for exporting and importing content entities in Drupal 10. It simplifies the process of transferring content between Drupal instances by allowing users to export content entities to YAML files and import them into another Drupal installation. This module is especially beneficial for users who want to export content without references just like config synchronization.

### Features
This module provides a user-friendly and efficient solution for content synchronization.

`drush content-entity-sync:export` (or `drush con-ex` / `drush cox`): This command allows you to export content entities. You can specify the entity type and optionally filter by bundle. For example, to export all nodes of the "article" bundle, you would run

`drush content-entity-sync:export node --bundle=article`.

`drush content-entity-sync:import` (or `drush con-im` / `drush coi`): This command is used to import content entities from YAML files. By default, it imports all content entities from the configured content directory. You can also specify the entity type and optionally filter by bundle. For example, to import only nodes of the "page" bundle, you would run

`drush content-entity-sync:import taxonomy_term --bundle=tags`.

### Post-Installation
It is important to note that before using the module, you need to set up the content directory where the exported YAML files will be stored and read from during the import process. This configuration is typically done in Drupal's settings.php file or in a dedicated configuration file.

```php
/**
 * Sets the directory path for storing exported content entities.
 *
 * The $settings['content_sync_directory'] configuration option specifies
 * the directory where the exported content entities will be stored as YAML
 * files during the export process. The value '../content/sync' represents a
 * relative path to the desired directory. In this case, it suggests that the
 * 'content' directory is located in the parent directory of the Drupal
 * installation, and within it, there is a 'sync' directory.
 *
 * Make sure that the specified directory is writable by the web server or the
 * Drupal application, allowing the Drupal Content Entity Sync module to
 * successfully write the exported YAML files to the specified directory during
 * the export process.
 *
 * Example: $settings['content_sync_directory'] = '../content/sync';
 */
$settings['content_sync_directory'] = '../content/sync';
```

By configuring this setting, the Drupal Content Entity Sync module will use the specified directory to store the exported YAML files. This directory serves as a storage location for the exported content entities, allowing them to be easily accessed and imported into other Drupal installations or used for backup purposes.
