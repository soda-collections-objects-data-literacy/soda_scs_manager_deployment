<?php

namespace Drupal\content_entity_sync\Services;

use Drupal\Core\Entity\ContentEntityInterface;
use Drupal\Core\Entity\EntityTypeManagerInterface;
use Drupal\Core\Serialization\Yaml;

class ContentEntityExportHandler {

  public function __construct(
    protected EntityTypeManagerInterface $entityTypeManager,
    protected ContentEntitySerializer $contentEntitySerializer,
  ) {}

  /**
   * @param string $entity_type
   * @param array $options
   *
   * @return \Generator
   * @throws \Drupal\Component\Plugin\Exception\InvalidPluginDefinitionException
   * @throws \Drupal\Component\Plugin\Exception\PluginNotFoundException
   */
  public function results(string $entity_type, array $options) {
    $storage = $this->entityTypeManager->getStorage($entity_type);

    // Build the entity query dynamically.
    $entity_query = $storage->getQuery()->accessCheck(FALSE);
    $keys = $storage->getEntityType()->getKeys();

    // Filter entities by bundle.
    if (!empty($options['bundle'])) {
      $bundles = explode(',', $options['bundle']);
      $entity_query->condition($keys['bundle'], $bundles, 'IN');
    }

    // Filter entities by bundle.
    if (!empty($options['ids'])) {
      $bundles = explode(',', $options['bundle']);
      $entity_query->condition($keys['id'], $bundles, 'IN');
    }

    foreach ($entity_query->execute() as $item) {
      yield $storage->load($item);
    }
  }

  public function serialize(ContentEntityInterface $entity): array {
    return $this->contentEntitySerializer->serialize($entity);
  }

  public function filename(ContentEntityInterface $entity) {
    return sprintf('%s.%s.%s.yml',
      $entity->getEntityTypeId(),
      $entity->bundle(),
      $entity->uuid()
    );
  }

  public function write(string $directory, string $filename, array $data) {
    $filepath = $directory . DIRECTORY_SEPARATOR . $filename;
    file_put_contents($filepath, Yaml::encode($data));
  }

}
