<?php

namespace Drupal\content_entity_sync\Drush\Commands;

use Consolidation\OutputFormatters\StructuredData\RowsOfFields;
use Drupal\Core\Entity\ContentEntityInterface;
use Drupal\Core\Entity\EntityInterface;
use Drupal\Core\Entity\FieldableEntityInterface;
use Drupal\Core\Serialization\Yaml;
use Drupal\Core\Site\Settings;
use Drupal\Core\Utility\Token;
use Drush\Attributes as CLI;
use Drush\Commands\DrushCommands;
use Symfony\Component\DependencyInjection\ContainerInterface;

/**
 * A Drush commandfile.
 */
final class ContentEntitySyncCommands extends DrushCommands {

  /**
   * Command description to export content entities.
   */
  #[CLI\Command(name: 'content_entity_sync:export', aliases: ['conex', 'cox'])]
  #[CLI\Argument(name: 'entity_type', description: 'Content entity type to export.')]
  #[CLI\Option  (name: 'bundle', description: 'Filters entities by the given bundle.')]
  #[CLI\Option(name: 'ids', description: 'Comma separated list of entity IDs.')]
  #[CLI\Usage(name: 'content_entity_sync:export node', description: 'Export all nodes.')]
  #[CLI\Usage(name: 'content_entity_sync:export --bundle=article node', description: 'Export articles only.')]
  public function exportCommand(string $entity_type, array $options = [
    'bundle' => self::OPT,
    'ids' => self::OPT
  ]) {
    $export = \Drupal::service('content_entity_sync.export');
    $directory = $this->getExistingContentDirectory();
    foreach ($export->results($entity_type, $options) as $entity) {
      $serialized = $export->serialize($entity);
      $export->write($directory, $export->filename($entity), $serialized);

      $this->logger()->success(dt('Exported @name', [
        '@name' => $entity->getConfigDependencyName()
      ]));
    }

    $this->logger()->info(dt('Content entity export completed.'));
  }

  /**
   * Import content entities.
   */
  #[CLI\Command(name: 'content_entity_sync:import', aliases: ['conim', 'coi'])]
  #[CLI\Argument(name: 'entity_type', description: 'Content entity type to import.')]
  #[CLI\Option(name: 'bundle', description: 'Filters entities by the given bundle.')]
  #[CLI\Usage(name: 'content_entity_sync:import --bundle=article node', description: 'Import all nodes of type article')]
  public function importCommand(string $entity_type, array $options = [
    'bundle' => self::OPT
  ]) {
    $import = \Drupal::service('content_entity_sync.import');
    $directory = $this->getExistingContentDirectory();
    foreach ($import->filter($directory, $entity_type) as $filepath) {
      $decoded = $import->read($filepath);
      $entity = $import->upsert($decoded, $options);

      if ($entity instanceof ContentEntityInterface) {
        $this->logger()->success(dt('Imported @name', [
          '@name' => $entity->getConfigDependencyName()
        ]));
      }
    }

    $this->logger()->info(dt('Content entity import completed.'));
  }

  /**
   * Get existing content directory.
   *
   * @return string
   * @throws \Exception
   */
  protected function getExistingContentDirectory() {
    $existing_content_dir = Settings::get('content_sync_directory');
    if (!is_dir($existing_content_dir)) {
      throw new \Exception(dt('Existing content directory @dir not found', ['@dir' => $existing_content_dir]));
    }
    return $existing_content_dir;
  }


}
