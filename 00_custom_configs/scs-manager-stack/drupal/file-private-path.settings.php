<?php

/**
 * @file
 * Private files directory — required for the private:// stream wrapper.
 *
 * Drupal only registers private:// when file_private_path is set
 * (see core/lib/Drupal/Core/CoreServiceProvider.php). SCS Manager snapshot
 * File entities use private://snapshots/… which must resolve under the same
 * tree as the snapshot bind mount: set this to the parent of
 * /var/scs-manager/snapshots (i.e. /var/scs-manager).
 *
 * Include from sites/default/settings.php if not already set:
 * @code
 * $scs_file_private = $app_root . '/../custom_configs/file-private-path.settings.php';
 * if (file_exists($scs_file_private)) {
 *   require $scs_file_private;
 * }
 * @endcode
 */
if (!isset($settings['file_private_path']) || $settings['file_private_path'] === '') {
  $settings['file_private_path'] = '/var/scs-manager';
}
