<?php

namespace Drupal\book_tree_menu;

use Drupal\book\BookManager;

/**
 * Overrides the BookManager service.
 */

class oscBookManager extends BookManager {

  /**
   * {@inheritdoc}
   */
  public function bookTreeAllData(int $bid, ?array $link = NULL, ?int $max_depth = NULL, ?int $min_depth = NULL): array {
    $tree = &drupal_static(__METHOD__, []);
    $language_interface = \Drupal::languageManager()->getCurrentLanguage();

    // Use $nid as a flag for whether the data being loaded is for the whole tree.
    $nid = $link['nid'] ?? 0;
    // Generate a cache ID (cid) specific for this $bid, $link, $language, and depth.
    $cid = 'book-links:' . $bid . ':all:' . $nid . ':' . $language_interface->getId() . ':' . (int) $max_depth . ':' . (int) $min_depth;

    if (!isset($tree[$cid])) {
      // If the tree data was not in the static cache, build $tree_parameters.
      $tree_parameters = [
        'min_depth' => 1,
        'min_depth' => $min_depth ?? 1, // Default to 1 if not provided.
      ];
      if ($nid) {
        $active_trail = $this->getActiveTrailIds($bid, $link);
        $tree_parameters['active_trail'] = $active_trail;
        $tree_parameters['active_trail'][] = $nid;
      }

      // Build the tree using the parameters; the resulting tree will be cached.
      $tree[$cid] = $this->bookTreeBuild($bid, $tree_parameters);
    }

    return $tree[$cid];
  }
}
