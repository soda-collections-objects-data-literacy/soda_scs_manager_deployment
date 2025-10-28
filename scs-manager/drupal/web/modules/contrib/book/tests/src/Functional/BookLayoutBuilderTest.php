<?php

declare(strict_types=1);

namespace Drupal\Tests\book\Functional;

use Drupal\layout_builder\Entity\LayoutBuilderEntityViewDisplay;
use Drupal\Tests\content_moderation\Traits\ContentModerationTestTrait;

/**
 * Tests interaction with layout builder.
 *
 * @group book
 */
class BookLayoutBuilderTest extends BookTestBase {

  use BookTestTrait;
  use ContentModerationTestTrait;

  /**
   * {@inheritdoc}
   */
  protected static $modules = [
    'book',
    'field_ui',
    'node',
    'layout_builder',
    'content_moderation',
  ];

  /**
   * Tests layout builder content types are un-affected by book.
   *
   * @throws \Drupal\Core\Entity\EntityStorageException
   * @throws \Behat\Mink\Exception\ResponseTextException
   */
  public function testBookWithLayoutBuilderInstalled(): void {
    $this->drupalCreateContentType(['type' => 'test_content_type']);
    LayoutBuilderEntityViewDisplay::load('node.test_content_type.default')
      ->enableLayoutBuilder()
      ->setOverridable()
      ->save();

    $workflow = $this->createEditorialWorkflow();
    $workflow->getTypePlugin()->addEntityTypeAndBundle('node', 'test_content_type');
    $workflow->save();

    $node = $this->createNode([
      'type' => 'test_content_type',
      'title' => 'The first node title',
      'moderation_state' => 'published',
    ]);

    $this->drupalLogin($this->drupalCreateUser([
      'configure any layout',
      'bypass node access',
      'create test_content_type content',
      'edit any test_content_type content',
      'use editorial transition create_new_draft',
      'use editorial transition publish',
      'create new books',
      'create book content',
      'edit any book content',
      'delete any book content',
      'add content to books',
      'reorder book pages',
      'add any content to books',
      'administer book outlines',
      'view any unpublished content',
      'view book revisions',
    ]));

    $this->assertTrue($node->isPublished());

    $this->drupalGet("node/{$node->id()}/layout");
    $this->assertEquals('Current state Published', $this->cssSelect('#edit-moderation-state-0-current')[0]->getText());

    $this->submitForm([
      'moderation_state[0][state]' => 'draft',
    ], 'Save layout');

    $this->assertSession()->pageTextContains('The layout override has been saved.');
  }

}
