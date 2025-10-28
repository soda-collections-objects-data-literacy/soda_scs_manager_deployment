<?php

namespace Drupal\custom_book_block\Plugin\Block;

use Drupal\book\Plugin\Block\BookNavigationBlock;
use Drupal\Component\Utility\SortArray;
use Drupal\Core\Form\FormStateInterface;
use Drupal\custom_book_block\ExpandBookManager;
use Drupal\custom_book_block\ProxyClass\ExpandBookManager as ProxyExpandBookManager;
use Drupal\node\NodeInterface;

/**
 * Provides a custom 'Book navigation' block.
 *
 * @Block(
 *   id = "custom_book_navigation",
 *   admin_label = @Translation("Custom book navigation"),
 *   category = @Translation("Menus")
 * )
 */
class CustomBookNavigationBlock extends BookNavigationBlock {

  /**
   * {@inheritdoc}
   */
  public function defaultConfiguration(): array {
    return parent::defaultConfiguration() + [
      'target_book' => '',
      'start_level' => 1,
      'max_levels' => '',
      'always_expand' => 1,
    ];
  }

  /**
   * {@inheritdoc}
   */
  public function blockForm($form, FormStateInterface $form_state): array {
    $form = parent::blockForm($form, $form_state);

    $options = ['' => 'Show all', 'dynamic' => 'Dynamic'];
    foreach ($this->bookManager->getAllBooks() as $book_id => $book) {
      $options[$book_id] = $book['title'];
    }
    $form['target_book'] = [
      '#type' => 'radios',
      '#title' => $this->t('Book to display'),
      '#options' => $options,
      '#default_value' => $this->configuration['target_book'],
      '#description' => $this->t('If left empty, all books will be shown. If Dynamic is selected, the block will detect the book menu to be displayed.'),
    ];

    $form['max_levels'] = [
      '#type' => 'number',
      '#title' => $this->t('Maximum levels to show'),
      '#min' => 0,
      '#default_value' => $this->configuration['max_levels'],
      '#description' => $this->t('If set to zero, all levels will be shown.'),
    ];

    $form['start_level'] = [
      '#type' => 'number',
      '#title' => $this->t('Start level'),
      '#min' => 1,
      '#default_value' => $this->configuration['start_level'],
      '#description' => $this->t('Start level, filter tree, show only active branch.'),
    ];

    $form['always_expand'] = [
      '#type' => 'checkbox',
      '#title' => $this->t('Always expand the menu'),
      '#default_value' => $this->configuration['always_expand'],
      '#description' => $this->t('If unchecked, will only be expanded in context.'),
    ];

    return $form;
  }

  /**
   * {@inheritdoc}
   */
  public function blockSubmit($form, FormStateInterface $form_state): void {
    parent::blockSubmit($form, $form_state);

    $this->configuration['target_book'] = $form_state->getValue('target_book');
    $this->configuration['max_levels'] = $form_state->getValue('max_levels');
    $this->configuration['start_level'] = $form_state->getValue('start_level');
    $this->configuration['always_expand'] = $form_state->getValue('always_expand');
  }

  /**
   * {@inheritdoc}
   */
  public function build(): array {
    $book_manager = $this->bookManager;
    if (!($book_manager instanceof ExpandBookManager || $book_manager instanceof ProxyExpandBookManager)) {
      return [];
    }

    $current_book_id = 0;
    $node = $this->routeMatch->getParameter('node');
    if ($node instanceof NodeInterface && !empty($node->book['bid'])) {
      $current_book_id = $node->book['bid'];
    }

    $max_levels = $this->configuration['max_levels'] ?: NULL;
    $start_level = $this->configuration['start_level'] ?: NULL;
    $target_book_id = $this->configuration['target_book'];
    if ($target_book_id === 'dynamic') {
      $target_book_id = $current_book_id;
    }
    $always_expand = $this->configuration['always_expand'];

    if ($this->configuration['block_mode'] === 'all pages') {
      $book_menus = [];
      $pseudo_tree = [0 => ['below' => FALSE]];
      $books = $this->bookManager->getAllBooks();
      uasort($books, [SortArray::class, 'sortByWeightElement']);

      foreach ($books as $book_id => $book) {
        // If a target book which is not this one, continue.
        if ($target_book_id && $book_id != $target_book_id) {
          continue;
        }

        // If only displaying the top node, no need to do additional queries.
        if ($max_levels == 1) {
          $book_node = $this->nodeStorage->load($book_id);
          if (!$book_node instanceof NodeInterface) {
            continue;
          }
          $book['access'] = $book_node->access('view');
          $pseudo_tree[0]['link'] = $book;
          $book_menus[$book_id] = $book_manager->bookTreeOutput($pseudo_tree);
        }
        else {
          // Retrieve the full menu, to the specified depth.
          $data = $book_manager->bookTreeAllData($book_id, $book, $max_levels, $start_level, $always_expand);
          $book_menus[$book_id] = $book_manager->bookTreeOutput($data);
          $book_menus[$book_id]['#items'][$book_id]['in_active_trail'] = FALSE;
          if ($book_menus[$book_id]['#items'][$book_id]['original_link']['bid'] == $current_book_id) {
            $book_menus[$book_id]['#items'][$book_id]['in_active_trail'] = TRUE;
          }
        }

        $book_menus[$book_id] += [
          '#book_title' => $book['title'],
        ];
      }

      if ($book_menus) {
        return [
          '#theme' => 'book_all_books_block',
        ] + $book_menus;
      }
    }

    elseif ($current_book_id) {
      // If not 'all pages' and a target book which is not this one, return.
      if ($target_book_id && $current_book_id != $target_book_id) {
        return [];
      }

      // Only display this block when the user is browsing a book and do
      // not show unpublished books.
      $nid = $this->nodeStorage->getQuery()
        ->accessCheck(TRUE)
        ->condition('nid', $node->book['bid'], '=')
        ->condition('status', NodeInterface::PUBLISHED)
        ->execute();

      // Only show the block if the user has view access for the top-level node.
      if ($nid) {
        $tree = $book_manager->bookTreeAllData($node->book['bid'], $node->book, $max_levels, $start_level, $always_expand);
        // There should only be one element at the top level.
        $data = array_shift($tree);
        if (!empty($data['below'])) {
          $below = $book_manager->bookTreeOutput($data['below']);
          if (!empty($below)) {
            return $below;
          }
        }
      }
    }

    return [];
  }

}
