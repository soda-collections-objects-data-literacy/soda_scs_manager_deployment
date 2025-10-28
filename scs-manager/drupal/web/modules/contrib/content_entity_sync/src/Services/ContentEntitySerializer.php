<?php

namespace Drupal\content_entity_sync\Services;

use Drupal\Core\Entity\ContentEntityInterface;
use Drupal\Core\Entity\EntityFieldManagerInterface;
use Drupal\Core\Entity\EntityInterface;
use Drupal\Core\Entity\EntityTypeManagerInterface;

/**
 * Serialize Content entities into an array.
 */
class ContentEntitySerializer {

  public function __construct(
    protected EntityTypeManagerInterface $entityTypeManager,
    protected EntityFieldManagerInterface $entityFieldManager
  ) { }

  public function serialize(ContentEntityInterface $entity): array {
    $values = $this->getCommonEntityMetadata($entity);
    $values['dependencies'] = $this->getBaseConfigDependencies($entity);

    $fields = $this->entityFieldManager->getFieldDefinitions($entity->getEntityTypeId(), $entity->bundle());
    $entity_references = [];

    $translations = [];
    $languages = $entity->getTranslationLanguages(FALSE);
    if ($entity->isTranslatable()) {
      foreach ($languages as $language) {
        $values['translations'][$language->getId()] = [];
        $translations[$language->getId()] = $entity->getTranslation($language->getId());
      }
    }

    foreach ($fields as $field) {
      if (isset($values[$field->getName()])) {
        continue;
      }


      if (!$field->getFieldStorageDefinition()->isBaseField()) {
        $values['dependencies']['config'][] = 'field.field.' . $field->getConfig($entity->bundle())->getOriginalId();
      }

      $field_value = $this->normalizeFieldValue($entity->get($field->getName())->getValue(), $field, $entity, $entity_references);

      if ($field->isTranslatable()) {
        foreach ($languages as $language) {
          $values['translations'][$language->getId()][$field->getName()] = $this->normalizeFieldValue(
            $translations[$language->getId()]->get($field->getName())->getValue(),
            $field,
            $translations[$language->getId()],
            $entity_references
          );
        }
      }

      $values['fields'][$field->getName()] = $field_value;
    }

    $entity_dependencies = array_unique($entity_references);
    if (count($entity_dependencies)) {
      $values['dependencies']['entity'] = array_values($entity_dependencies);
    }

    return $values;
  }

  protected function normalizeFieldValue($field_value, $field, $entity, &$entity_references) {
    foreach ($field_value as $item) {
      if (empty($item['target_id'])) {
        continue;
      }

      $referenced_entity_type = $field->getFieldStorageDefinition()->getPropertyDefinition('entity')->getConstraint('EntityType');
      $referenced_entity = $this->entityTypeManager->getStorage($referenced_entity_type)->load($item['target_id']);

      $entity_references[] = $referenced_entity->getConfigDependencyName();
    }

    if ($field->getConfig($entity->bundle())->getFieldStorageDefinition()->getCardinality() === 1 && count($field_value)) {
      $field_value = array_shift($field_value);
    }

    if (count($field_value) === 1 && isset($field_value['value'])) {
      $field_value = $field_value['value'];
    }

    return $field_value;
  }

  protected function getCommonEntityMetadata(ContentEntityInterface $entity) {
    return  [
      'uuid' => $entity->uuid(),
      'langcode' => $entity->language()->getId(),
      'type' => $entity->getEntityTypeId(),
      'bundle' => $entity->bundle(),
      'id' => $entity->id(),
      'dependencies' => [],
      'fields' => [],
    ];
  }

  protected function getBaseConfigDependencies(ContentEntityInterface $entity) {
    return [
      'config' => [
        sprintf('%s.%s_type.%s', $entity->getEntityTypeId(), $entity->getEntityTypeId(), $entity->bundle()),
      ],
    ];
  }

}
