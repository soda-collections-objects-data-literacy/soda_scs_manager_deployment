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

/* @help_topics/book.adding.html.twig */
class __TwigTemplate_3211a9f1733d26aec229468874b91ee0 extends Template
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
        $context["node_add_link_text"] = ('' === $tmp = \Twig\Extension\CoreExtension::captureOutput((function () use (&$context, $macros, $blocks) {
            yield t("Add content", []);
            yield from [];
        })())) ? '' : new Markup($tmp, $this->env->getCharset());
        // line 10
        $context["node_add_link"] = $this->extensions['Drupal\Core\Template\TwigExtension']->renderVar($this->extensions['Drupal\help\HelpTwigExtension']->getRouteLink(($context["node_add_link_text"] ?? null), "node.add_page"));
        // line 11
        $context["configuring_topic"] = $this->extensions['Drupal\Core\Template\TwigExtension']->renderVar($this->extensions['Drupal\help\HelpTwigExtension']->getTopicLink("book.configuring"));
        // line 12
        yield "<h2>";
        yield t("Goal", []);
        yield "</h2>
<p>";
        // line 13
        yield t("Add a page to an existing book.", []);
        yield "</p>
<h2>";
        // line 14
        yield t("Steps", []);
        yield "</h2>
<ol>
  <li>";
        // line 16
        yield t("In the <em>Manage</em> administrative menu, navigate to <em>Content</em> &gt; <em>@node_add_link</em> &gt; <em>Book page</em>. If you have configured additional content types that can be added to books, you can substitute a different content type for <em>Book page</em>; see @configuring_topic for more information.", ["@node_add_link" => ($context["node_add_link"] ?? null), "@configuring_topic" => ($context["configuring_topic"] ?? null), ]);
        yield "</li>
  <li>";
        // line 17
        yield t("Enter a title for the page and some text for the body of the page.", []);
        yield "</li>
  <li>";
        // line 18
        yield t("In the vertical tabs area, click <em>Book Outline</em>. Select the book you want to add the page to in the <em>Book</em> select list. If you want to insert this page into the book hierarchy, also select the desired parent page in the <em>Parent item</em> select list.", []);
        yield "</li>
  <li>";
        // line 19
        yield t("Select the desired weight for the page in the <em>Weight</em> select list (pages with the same parent item are ordered from lowest to highest weight).", []);
        yield "</li>
  <li>";
        // line 20
        yield t("Click <em>Save</em> to add the page to the book.", []);
        yield "</li>
</ol>";
        yield from [];
    }

    /**
     * @codeCoverageIgnore
     */
    public function getTemplateName(): string
    {
        return "@help_topics/book.adding.html.twig";
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
        return array (  83 => 20,  79 => 19,  75 => 18,  71 => 17,  67 => 16,  62 => 14,  58 => 13,  53 => 12,  51 => 11,  49 => 10,  44 => 9,);
    }

    public function getSourceContext(): Source
    {
        return new Source("", "@help_topics/book.adding.html.twig", "/opt/drupal/web/modules/contrib/book/help_topics/book.adding.html.twig");
    }
    
    public function checkSecurity()
    {
        static $tags = ["set" => 9, "trans" => 9];
        static $filters = ["escape" => 16];
        static $functions = ["render_var" => 10, "help_route_link" => 10, "help_topic_link" => 11];

        try {
            $this->sandbox->checkSecurity(
                ['set', 'trans'],
                ['escape'],
                ['render_var', 'help_route_link', 'help_topic_link'],
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
