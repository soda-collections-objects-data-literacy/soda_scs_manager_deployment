<?php

namespace Drupal\custom_book_block;

use Drupal\book\BookManager;
use Drupal\Core\Language\LanguageInterface;
use Drupal\Core\Template\Attribute;
use Drupal\Core\Url;
use Drupal\node\NodeInterface;

/**
 * Overrides class for BookManager service.
 */
class ExpandBookManager extends BookManager {

  /**
   * {@inheritdoc}
   */
  public function bookTreeAllData($bid, $link = NULL, $max_depth = NULL, $start_level = NULL, int $always_expand = 0): array {

    $tree = &drupal_static(__METHOD__, []);
    $language_interface = $this->languageManager->getCurrentLanguage();

    // Use $nid as a flag for whether the data being loaded is for the whole
    // tree.
    $nid = $link['nid'] ?? 0;

    // Generate a cache ID (cid) specific for this $bid, $link, $language, and
    // depth.
    $cid = 'book-links:' . $bid . ':all:' . $nid . ':' . $language_interface->getId() . ':' . (int) $max_depth;

    if (!isset($tree[$cid])) {
      // If the tree data was not in the static cache, build $tree_parameters.
      $tree_parameters = [
        'min_depth' => $start_level ?? 1,
        'max_depth' => $max_depth,
      ];

      if ($nid && $link !== NULL) {
        $active_trail = $this->getActiveTrailIds((string) $bid, $link);

        // Setting the 'expanded' value to $active_trail would be same as core.
        if ($always_expand) {
          $tree_parameters['expanded'] = [];
        }
        else {
          $tree_parameters['expanded'] = $active_trail;
        }
        $tree_parameters['active_trail'] = $active_trail;
        $tree_parameters['active_trail'][] = $nid;
      }

      if ($start_level && $start_level > 1) {
        $book_link = $this->loadBookLink($nid);
        if (!empty($book_link['p' . $start_level]) && $book_link['p' . $start_level] > 0) {
          $tree_parameters['conditions']['p' . $start_level] = $book_link['p' . $start_level];
        }
      }

      // Build the tree using the parameters; the resulting tree will be cached.
      $tree[$cid] = $this->bookTreeBuild($bid, $tree_parameters);
    }

    return $tree[$cid];
  }

  /**
   * {@inheritdoc}
   */
  protected function buildItems(array $tree): array {

    $items = [];
    $langcode = $this->languageManager->getCurrentLanguage(LanguageInterface::TYPE_CONTENT)->getId();
    $node = $this->route_match->getParameter('node');

    foreach ($tree as $data) {
      $element = [];

      // Generally we only deal with visible links, but just in case.
      if (!$data['link']['access']) {
        continue;
      }

      // Set a class for the <li> tag. Since $data['below'] may contain local
      // tasks, only set 'expanded' to true if the link also has children within
      // the current book.
      $element['is_expanded'] = FALSE;
      $element['is_collapsed'] = FALSE;
      if ($data['link']['has_children'] && $data['below']) {
        $element['is_expanded'] = TRUE;
      }
      elseif ($data['link']['has_children']) {
        $element['is_collapsed'] = TRUE;
      }

      // Set a helper variable to indicate whether the link is in the active
      // trail.
      $element['in_active_trail'] = FALSE;
      if ($data['link']['in_active_trail']) {
        $element['in_active_trail'] = TRUE;
      }

      // Set a helper variable to indicate whether the link is the active link.
      $element['is_active'] = FALSE;
      if (($node instanceof NodeInterface) && $data['link']['nid'] === $node->id()) {
        $element['is_active'] = TRUE;
      }

      // Allow book-specific theme overrides.
      $element['attributes'] = new Attribute();
      $element['title'] = $data['link']['title'];
      $element['url'] = Url::fromUri('entity:node/' . $data['link']['nid'], [
        'langcode' => $langcode,
      ]);

      $element['localized_options'] = !empty($data['link']['localized_options']) ? $data['link']['localized_options'] : [];
      $element['localized_options']['set_active_class'] = TRUE;
      $element['below'] = $data['below'] ? $this->buildItems($data['below']) : [];
      $element['original_link'] = $data['link'];

      // Index using the link's unique nid.
      $items[$data['link']['nid']] = $element;
    }

    return $items;
  }

}
