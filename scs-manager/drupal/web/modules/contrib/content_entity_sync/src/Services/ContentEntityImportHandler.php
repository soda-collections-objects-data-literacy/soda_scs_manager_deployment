<?php

namespace Drupal\content_entity_sync\Services;

use Drupal\Core\Entity\EntityInterface;
use Drupal\Core\Entity\EntityTypeManagerInterface;
use Drupal\Core\Entity\FieldableEntityInterface;
use Drupal\Core\Entity\TranslatableInterface;
use Drupal\Core\Serialization\Yaml;

class ContentEntityImportHandler {

  public function __construct(
    protected EntityTypeManagerInterface $entityTypeManager
  ) { }

  public function filter($directory, $entity_type) {

    foreach (scandir($directory) as $item) {
      $path = $directory . DIRECTORY_SEPARATOR . $item;
      if (!is_file($path)) {
        continue;
      }
      $type = explode('.', $item, 2);
      $type = array_shift($type);
      if (!empty($entity_type) && $type !== $entity_type) {
        continue;
      }

      yield $path;
    }
  }

  public function read($filepath) {
    return Yaml::decode(file_get_contents($filepath));
  }

  public function upsert($content, $options) {
    $storage = $this->entityTypeManager->getStorage($content['type']);

    $entity = $storage->load($content['id']);

    if ($entity instanceof EntityInterface && !empty($options['bundle']) && $entity->bundle() !== $options['bundle']) {
      return NULL;
    }

    if ($entity instanceof FieldableEntityInterface) {
      foreach ($content['fields'] as $name => $value) {
        if (is_array($value)) {
          foreach ($value as $key => $item) {
            if (str_starts_with($key, '_')) {
              unset($value[$key]);
            }
          }
        }

        $entity->set($name, $value);
      }
      $entity->save();
      $this->handleTranslations($entity, $content);

      return $entity;
    }

    $entity_type = $storage->getEntityType();
    $entity_keys = $entity_type->getKeys();
    $bundle_key = $entity_keys['bundle'] ?? 'type';

    $entity = $storage->create([$bundle_key => $content['bundle']] + $content['fields']);
    $entity->save();

    $this->handleTranslations($entity, $content);

    return $entity;
  }

  protected function handleTranslations($entity, $content) {
    if (!$entity instanceof TranslatableInterface) {
      return;
    }

    foreach ($content['translations'] as $langcode => $translation) {
      if (!$entity->hasTranslation($langcode)) {
        $translated_entity = $entity->addTranslation($langcode, $translation);
        $translated_entity->save();
        continue;
      }

      $translated_entity = $entity->getTranslation($langcode);
      foreach ($translation as $field => $value) {
        $translated_entity->set($field, $value);
      }
      $translated_entity->save();

    }
  }

}
