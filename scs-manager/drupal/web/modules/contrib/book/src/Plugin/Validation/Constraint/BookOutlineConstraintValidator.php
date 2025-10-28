<?php

namespace Drupal\book\Plugin\Validation\Constraint;

use Drupal\Core\DependencyInjection\ContainerInjectionInterface;
use Drupal\Core\Config\ConfigFactoryInterface;
use Drupal\Core\Session\AccountProxyInterface;
use Drupal\Core\Url;
use Drupal\book\BookManagerInterface;
use Symfony\Component\DependencyInjection\ContainerInterface;
use Symfony\Component\Validator\Constraint;
use Symfony\Component\Validator\ConstraintValidator;

/**
 * Constraint validator for changing the book outline in pending revisions.
 */
class BookOutlineConstraintValidator extends ConstraintValidator implements ContainerInjectionInterface {

  /**
   * Creates a new BookOutlineConstraintValidator instance.
   *
   * @param \Drupal\book\BookManagerInterface $bookManager
   *   The book manager.
   * @param \Drupal\Core\Session\AccountProxyInterface $currentUser
   *   The current user.
   * @param \Drupal\Core\Config\ConfigFactoryInterface $configFactory
   *   Configuration factory.
   */
  public function __construct(
    protected BookManagerInterface $bookManager,
    protected AccountProxyInterface $currentUser,
    protected ConfigFactoryInterface $configFactory,
  ) {}

  /**
   * {@inheritdoc}
   */
  public static function create(ContainerInterface $container): static {
    return new static(
      $container->get('book.manager'),
      $container->get('current_user'),
      $container->get('config.factory'),
    );
  }

  /**
   * {@inheritdoc}
   */
  public function validate($value, Constraint $constraint): void {
    // Validate the book structure when the user has access to manage book
    // outlines. When the user can manage book outlines, the book variable will
    // be populated even if the node is not part of the book. If the user cannot
    // manage book outlines, the book variable will be empty, and we can safely
    // ignore the constraints as the outline cannot be changed by this user.
    if (isset($value) && !empty($value->book) && !$value->isNew() && !$value->isDefaultRevision()) {

      // Skip validation if the node type is not allowed in book outlines
      // This prevents BookOutlineConstraint from interfering with
      // Layout Builder operations on content types that aren't book enabled
      // Get list of allowed content types for books.
      $allowed_types = $this->configFactory->get('book.settings')->get('allowed_types');
      // Get the node's content type (bundle)
      $node_type = $value->bundle();

      if (in_array($node_type, $allowed_types)) {
        /** @var \Drupal\Core\Entity\ContentEntityInterface $original */
        $original = $this->bookManager->loadBookLink($value->id(), FALSE) ?: [
          'bid' => 0,
          'weight' => 0,
        ];
        if (empty($original['pid'])) {
          $original['pid'] = -1;
        }

        if ($value->book['bid'] != $original['bid']) {
          if ($this->currentUser->hasPermission('administer book outlines')) {
            $this->context->buildViolation($constraint->messageWithLink, [
              ':link' => Url::fromRoute('book.admin')->toString(),
            ])
              ->atPath('book.bid')
              ->setInvalidValue($value)
              ->addViolation();
          }
          else {
            $this->context->buildViolation($constraint->message)
              ->atPath('book.bid')
              ->setInvalidValue($value)
              ->addViolation();
          }
        }
        if ($value->book['pid'] != $original['pid']) {
          if ($this->currentUser->hasPermission('administer book outlines')) {
            $this->context->buildViolation($constraint->messageWithLink, [
              ':link' => Url::fromRoute('book.admin')->toString(),
            ])
              ->atPath('book.pid')
              ->setInvalidValue($value)
              ->addViolation();
          }
          else {
            $this->context->buildViolation($constraint->message)
              ->atPath('book.pid')
              ->setInvalidValue($value)
              ->addViolation();
          }
        }
        if ($value->book['weight'] != $original['weight']) {
          if ($this->currentUser->hasPermission('administer book outlines')) {
            $this->context->buildViolation($constraint->messageWithLink, [
              ':link' => Url::fromRoute('book.admin')->toString(),
            ])
              ->atPath('book.weight')
              ->setInvalidValue($value)
              ->addViolation();
          }
          else {
            $this->context->buildViolation($constraint->message)
              ->atPath('book.weight')
              ->setInvalidValue($value)
              ->addViolation();
          }
        }
      }
    }
  }

}
