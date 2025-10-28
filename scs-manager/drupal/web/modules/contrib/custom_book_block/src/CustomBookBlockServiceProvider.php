<?php

namespace Drupal\custom_book_block;

use Drupal\Core\DependencyInjection\ContainerBuilder;
use Drupal\Core\DependencyInjection\ServiceProviderBase;

/**
 * Defines a book manager which extends the core BookManager class.
 */
class CustomBookBlockServiceProvider extends ServiceProviderBase {

  /**
   * {@inheritdoc}
   */
  public function alter(ContainerBuilder $container): void {
    $definition = $container->getDefinition('book.manager');
    $definition->setClass(ExpandBookManager::class);
  }

}
