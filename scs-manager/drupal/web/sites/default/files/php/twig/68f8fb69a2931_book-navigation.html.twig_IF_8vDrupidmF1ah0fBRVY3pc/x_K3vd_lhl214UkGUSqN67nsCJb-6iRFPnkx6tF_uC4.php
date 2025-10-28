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

/* modules/contrib/book/modules/book_olivero/templates/book-navigation.html.twig */
class __TwigTemplate_371c9f14b0aec38b6b0cf6f8c475248a extends Template
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
        // line 32
        yield $this->extensions['Drupal\Core\Template\TwigExtension']->escapeFilter($this->env, $this->extensions['Drupal\Core\Template\TwigExtension']->attachLibrary("book_olivero/book_olivero.navigation"), "html", null, true);
        yield "
";
        // line 33
        if ((($context["tree"] ?? null) || ($context["has_links"] ?? null))) {
            // line 34
            yield "  <nav id=\"book-navigation-";
            yield $this->extensions['Drupal\Core\Template\TwigExtension']->escapeFilter($this->env, ($context["book_id"] ?? null), "html", null, true);
            yield "\" class=\"book-navigation\" role=\"navigation\" aria-labelledby=\"book-label-";
            yield $this->extensions['Drupal\Core\Template\TwigExtension']->escapeFilter($this->env, ($context["book_id"] ?? null), "html", null, true);
            yield "\">
    ";
            // line 35
            yield $this->extensions['Drupal\Core\Template\TwigExtension']->escapeFilter($this->env, ($context["tree"] ?? null), "html", null, true);
            yield "
    ";
            // line 36
            if ((($tmp = ($context["has_links"] ?? null)) && $tmp instanceof Markup ? (string) $tmp : $tmp)) {
                // line 37
                yield "      <h2 class=\"visually-hidden\" id=\"book-label-";
                yield $this->extensions['Drupal\Core\Template\TwigExtension']->escapeFilter($this->env, ($context["book_id"] ?? null), "html", null, true);
                yield "\">";
                yield $this->extensions['Drupal\Core\Template\TwigExtension']->renderVar(t("Book traversal links for"));
                yield " ";
                yield $this->extensions['Drupal\Core\Template\TwigExtension']->escapeFilter($this->env, ($context["book_title"] ?? null), "html", null, true);
                yield "</h2>
      <ul class=\"book-pager\">
      ";
                // line 39
                if ((($tmp = ($context["prev_url"] ?? null)) && $tmp instanceof Markup ? (string) $tmp : $tmp)) {
                    // line 40
                    yield "        <li class=\"book-pager__item book-pager__item--previous\">
          <a class=\"book-pager__link book-pager__link--previous\" href=\"";
                    // line 41
                    yield $this->extensions['Drupal\Core\Template\TwigExtension']->escapeFilter($this->env, ($context["prev_url"] ?? null), "html", null, true);
                    yield "\" rel=\"prev\" title=\"";
                    yield $this->extensions['Drupal\Core\Template\TwigExtension']->renderVar(t("Go to previous page"));
                    yield "\">";
                    yield $this->extensions['Drupal\Core\Template\TwigExtension']->escapeFilter($this->env, ($context["prev_title"] ?? null), "html", null, true);
                    yield "</a>
        </li>
      ";
                }
                // line 44
                yield "      ";
                if ((($tmp = ($context["parent_url"] ?? null)) && $tmp instanceof Markup ? (string) $tmp : $tmp)) {
                    // line 45
                    yield "        <li class=\"book-pager__item book-pager__item--center\">
          <a class=\"book-pager__link book-pager__link--center\" href=\"";
                    // line 46
                    yield $this->extensions['Drupal\Core\Template\TwigExtension']->escapeFilter($this->env, ($context["parent_url"] ?? null), "html", null, true);
                    yield "\" title=\"";
                    yield $this->extensions['Drupal\Core\Template\TwigExtension']->renderVar(t("Go to parent page"));
                    yield "\">";
                    yield $this->extensions['Drupal\Core\Template\TwigExtension']->renderVar(t("Up"));
                    yield "</a>
        </li>
      ";
                }
                // line 49
                yield "      ";
                if ((($tmp = ($context["next_url"] ?? null)) && $tmp instanceof Markup ? (string) $tmp : $tmp)) {
                    // line 50
                    yield "        <li class=\"book-pager__item book-pager__item--next\">
          <a class=\"book-pager__link book-pager__link--next\" href=\"";
                    // line 51
                    yield $this->extensions['Drupal\Core\Template\TwigExtension']->escapeFilter($this->env, ($context["next_url"] ?? null), "html", null, true);
                    yield "\" rel=\"next\" title=\"";
                    yield $this->extensions['Drupal\Core\Template\TwigExtension']->renderVar(t("Go to next page"));
                    yield "\">";
                    yield $this->extensions['Drupal\Core\Template\TwigExtension']->escapeFilter($this->env, ($context["next_title"] ?? null), "html", null, true);
                    yield "</a>
       </li>
      ";
                }
                // line 54
                yield "    </ul>
    ";
            }
            // line 56
            yield "  </nav>
";
        }
        $this->env->getExtension('\Drupal\Core\Template\TwigExtension')
            ->checkDeprecations($context, ["tree", "has_links", "book_id", "book_title", "prev_url", "prev_title", "parent_url", "next_url", "next_title"]);        yield from [];
    }

    /**
     * @codeCoverageIgnore
     */
    public function getTemplateName(): string
    {
        return "modules/contrib/book/modules/book_olivero/templates/book-navigation.html.twig";
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
        return array (  124 => 56,  120 => 54,  110 => 51,  107 => 50,  104 => 49,  94 => 46,  91 => 45,  88 => 44,  78 => 41,  75 => 40,  73 => 39,  63 => 37,  61 => 36,  57 => 35,  50 => 34,  48 => 33,  44 => 32,);
    }

    public function getSourceContext(): Source
    {
        return new Source("", "modules/contrib/book/modules/book_olivero/templates/book-navigation.html.twig", "/opt/drupal/web/modules/contrib/book/modules/book_olivero/templates/book-navigation.html.twig");
    }
    
    public function checkSecurity()
    {
        static $tags = ["if" => 33];
        static $filters = ["escape" => 32, "t" => 37];
        static $functions = ["attach_library" => 32];

        try {
            $this->sandbox->checkSecurity(
                ['if'],
                ['escape', 't'],
                ['attach_library'],
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
