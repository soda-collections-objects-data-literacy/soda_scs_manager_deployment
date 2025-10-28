<?php

use Twig\Environment;
use Twig\Error\LoaderError;
use Twig\Error\RuntimeError;
use Twig\Extension\CoreExtension;
use Twig\Extension\SandboxExtension;
use Twig\Markup;
use Twig\Sandbox\SecurityError;
use Twig\Sandbox\SecurityNotAllowedTagError;
use Twig\Sandbox\SecurityNotAllowedFilterError;
use Twig\Sandbox\SecurityNotAllowedFunctionError;
use Twig\Source;
use Twig\Template;
use Twig\TemplateWrapper;

/* @help_topics/book.creating.html.twig */
class __TwigTemplate_ca18af210b638e54a1572f55038ff5d8 extends Template
{
    private Source $source;
    /**
     * @var array<string, Template>
     */
    private array $macros = [];

    public function __construct(Environment $env)
    {
        parent::__construct($env);

        $this->source = $this->getSourceContext();

        $this->parent = false;

        $this->blocks = [
        ];
        $this->sandbox = $this->extensions[SandboxExtension::class];
        $this->checkSecurity();
    }

    protected function doDisplay(array $context, array $blocks = []): iterable
    {
        $macros = $this->macros;
        // line 9
        yield "<h2>";
        yield t("Goal", []);
        yield "</h2>
<p>";
        // line 10
        yield t("Create a new book.", []);
        yield "</p>
<h2>";
        // line 11
        yield t("Steps", []);
        yield "</h2>
<ol>
  <li>";
        // line 13
        yield t("In the <em>Manage</em> administrative menu, navigate to <em>Content</em> &gt; <em>Add content</em> &gt; <em>Book page</em>. If you have configured additional content types that can be added to books, you can substitute a different content type for <em>Book page</em>.", []);
        yield "</li>
  <li>";
        // line 14
        yield t("Enter a title for the book, and if desired, some text for the body of the book's title page.", []);
        yield "</li>
  <li>";
        // line 15
        yield t("In the vertical tabs area, click <em>Book Outline</em>. Select <em>- Create a new book -</em> from the <em>Book</em> select list.", []);
        yield "</li>
  <li>";
        // line 16
        yield t("Click <em>Save</em> to create the book.", []);
        yield "</li>
</ol>";
        yield from [];
    }

    /**
     * @codeCoverageIgnore
     */
    public function getTemplateName(): string
    {
        return "@help_topics/book.creating.html.twig";
    }

    /**
     * @codeCoverageIgnore
     */
    public function isTraitable(): bool
    {
        return false;
    }

    /**
     * @codeCoverageIgnore
     */
    public function getDebugInfo(): array
    {
        return array (  70 => 16,  66 => 15,  62 => 14,  58 => 13,  53 => 11,  49 => 10,  44 => 9,);
    }

    public function getSourceContext(): Source
    {
        return new Source("", "@help_topics/book.creating.html.twig", "/opt/drupal/web/modules/contrib/book/help_topics/book.creating.html.twig");
    }
    
    public function checkSecurity()
    {
        static $tags = ["trans" => 9];
        static $filters = [];
        static $functions = [];

        try {
            $this->sandbox->checkSecurity(
                ['trans'],
                [],
                [],
                $this->source
            );
        } catch (SecurityError $e) {
            $e->setSourceContext($this->source);

            if ($e instanceof SecurityNotAllowedTagError && isset($tags[$e->getTagName()])) {
                $e->setTemplateLine($tags[$e->getTagName()]);
            } elseif ($e instanceof SecurityNotAllowedFilterError && isset($filters[$e->getFilterName()])) {
                $e->setTemplateLine($filters[$e->getFilterName()]);
            } elseif ($e instanceof SecurityNotAllowedFunctionError && isset($functions[$e->getFunctionName()])) {
                $e->setTemplateLine($functions[$e->getFunctionName()]);
            }

            throw $e;
        }

    }
}
