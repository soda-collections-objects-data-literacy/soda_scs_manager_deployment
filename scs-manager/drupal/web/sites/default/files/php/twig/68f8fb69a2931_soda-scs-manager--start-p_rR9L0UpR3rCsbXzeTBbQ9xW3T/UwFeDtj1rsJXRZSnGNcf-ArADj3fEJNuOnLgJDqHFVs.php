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

/* modules/custom/soda_scs_manager/templates/pages/soda-scs-manager--start-page.html.twig */
class __TwigTemplate_b1e4bf9f7020c83ac03b8dde529ee77b extends Template
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
        // line 12
        yield "<div";
        yield $this->extensions['Drupal\Core\Template\TwigExtension']->escapeFilter($this->env, CoreExtension::getAttribute($this->env, $this->source, ($context["attributes"] ?? null), "addClass", ["soda-scs-manager--start-page"], "method", false, false, true, 12), "html", null, true);
        yield ">
  <div class=\"soda-scs-manager--header-section\">
    <h1>Hi ";
        // line 14
        yield $this->extensions['Drupal\Core\Template\TwigExtension']->escapeFilter($this->env, ($context["user"] ?? null), "html", null, true);
        yield "!</h1>
  </div>

  <div class=\"soda-scs-manager--tiles-container soda-scs-manager--view--grid\">
    <!-- Dashboard Tile -->
    <a href=\"";
        // line 19
        yield $this->extensions['Drupal\Core\Template\TwigExtension']->renderVar($this->extensions['Drupal\Core\Template\TwigExtension']->getPath("soda_scs_manager.dashboard"));
        yield "\" class=\"soda-scs-manager--tile-card\">
      <div class=\"soda-scs-manager--icon-wrapper\">
        <svg fill=\"currentColor\" viewBox=\"0 0 20 20\" xmlns=\"http://www.w3.org/2000/svg\">
          <path fill-rule=\"evenodd\" d=\"M3 5a2 2 0 012-2h10a2 2 0 012 2v8a2 2 0 01-2 2h-2.22l.123.489.804.804A1 1 0 0113 18H7a1 1 0 01-.707-1.707l.804-.804L7.22 15H5a2 2 0 01-2-2V5zm5.771 7H5V5h10v7H8.771z\" clip-rule=\"evenodd\"></path>
        </svg>
      </div>
      <h2>";
        // line 25
        yield $this->extensions['Drupal\Core\Template\TwigExtension']->renderVar(t("Dashboard"));
        yield "</h2>
      <p>";
        // line 26
        yield $this->extensions['Drupal\Core\Template\TwigExtension']->renderVar(t("Manage your applications in use"));
        yield "</p>
    </a>

    <!-- Catalogue Tile -->
    <a href=\"";
        // line 30
        yield $this->extensions['Drupal\Core\Template\TwigExtension']->renderVar($this->extensions['Drupal\Core\Template\TwigExtension']->getPath("soda_scs_manager.catalogue"));
        yield "\" class=\"soda-scs-manager--tile-card\">
      <div class=\"soda-scs-manager--icon-wrapper\">
        <svg fill=\"currentColor\" viewBox=\"0 0 20 20\" xmlns=\"http://www.w3.org/2000/svg\">
          <path d=\"M3 1a1 1 0 000 2h1.22l.305 1.222a.997.997 0 00.01.042l1.358 5.43-.893.892C3.74 11.846 4.632 14 6.414 14H15a1 1 0 000-2H6.414l1-1H14a1 1 0 00.894-.553l3-6A1 1 0 0017 3H6.28l-.31-1.243A1 1 0 005 1H3z\"></path>
          <path d=\"M16 16.5a1.5 1.5 0 11-3 0 1.5 1.5 0 013 0zM6.5 18a1.5 1.5 0 100-3 1.5 1.5 0 000 3z\"></path>
        </svg>
      </div>
      <h2>";
        // line 37
        yield $this->extensions['Drupal\Core\Template\TwigExtension']->renderVar(t("Catalogue"));
        yield "</h2>
      <p>";
        // line 38
        yield $this->extensions['Drupal\Core\Template\TwigExtension']->renderVar(t("Browse available applications"));
        yield "</p>
    </a>

    <!-- Documentation Tile -->
    <a href=\"/docs\" class=\"soda-scs-manager--tile-card\">
      <div class=\"soda-scs-manager--icon-wrapper\">
        <svg fill=\"currentColor\" viewBox=\"0 0 20 20\" xmlns=\"http://www.w3.org/2000/svg\">
          <path d=\"M9 4.804A7.968 7.968 0 005.5 4c-1.255 0-2.443.29-3.5.804v10A7.969 7.969 0 015.5 14c1.669 0 3.218.51 4.5 1.385A7.962 7.962 0 0114.5 14c1.255 0 2.443.29 3.5.804v-10A7.968 7.968 0 0014.5 4c-1.255 0-2.443.29-3.5.804V12a1 1 0 11-2 0V4.804z\"></path>
        </svg>
      </div>
      <h2>";
        // line 48
        yield $this->extensions['Drupal\Core\Template\TwigExtension']->renderVar(t("Documentation"));
        yield "</h2>
      <p>";
        // line 49
        yield $this->extensions['Drupal\Core\Template\TwigExtension']->renderVar(t("Read guides and documentation"));
        yield "</p>
    </a>

    <!-- Administration Tile -->
    <a href=\"/admin/config/soda-scs-manager\" class=\"soda-scs-manager--tile-card\">
      <div class=\"soda-scs-manager--icon-wrapper\">
        <svg fill=\"currentColor\" viewBox=\"0 0 20 20\" xmlns=\"http://www.w3.org/2000/svg\">
          <path fill-rule=\"evenodd\" d=\"M11.49 3.17c-.38-1.56-2.6-1.56-2.98 0a1.532 1.532 0 01-2.286.948c-1.372-.836-2.942.734-2.106 2.106.54.886.061 2.042-.947 2.287-1.561.379-1.561 2.6 0 2.978a1.532 1.532 0 01.947 2.287c-.836 1.372.734 2.942 2.106 2.106a1.532 1.532 0 012.287.947c.379 1.561 2.6 1.561 2.978 0a1.533 1.533 0 012.287-.947c1.372.836 2.942-.734 2.106-2.106a1.533 1.533 0 01.947-2.287c1.561-.379 1.561-2.6 0-2.978a1.532 1.532 0 01-.947-2.287c.836-1.372-.734-2.942-2.106-2.106a1.532 1.532 0 01-2.287-.947zM10 13a3 3 0 100-6 3 3 0 000 6z\" clip-rule=\"evenodd\"></path>
        </svg>
      </div>
      <h2>";
        // line 59
        yield $this->extensions['Drupal\Core\Template\TwigExtension']->renderVar(t("Administration"));
        yield "</h2>
      <p>";
        // line 60
        yield $this->extensions['Drupal\Core\Template\TwigExtension']->renderVar(t("Configure system settings"));
        yield "</p>
    </a>
  </div>
</div>
";
        $this->env->getExtension('\Drupal\Core\Template\TwigExtension')
            ->checkDeprecations($context, ["attributes", "user"]);        yield from [];
    }

    /**
     * @codeCoverageIgnore
     */
    public function getTemplateName(): string
    {
        return "modules/custom/soda_scs_manager/templates/pages/soda-scs-manager--start-page.html.twig";
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
        return array (  126 => 60,  122 => 59,  109 => 49,  105 => 48,  92 => 38,  88 => 37,  78 => 30,  71 => 26,  67 => 25,  58 => 19,  50 => 14,  44 => 12,);
    }

    public function getSourceContext(): Source
    {
        return new Source("", "modules/custom/soda_scs_manager/templates/pages/soda-scs-manager--start-page.html.twig", "/opt/drupal/web/modules/custom/soda_scs_manager/templates/pages/soda-scs-manager--start-page.html.twig");
    }
    
    public function checkSecurity()
    {
        static $tags = [];
        static $filters = ["escape" => 12, "t" => 25];
        static $functions = ["path" => 19];

        try {
            $this->sandbox->checkSecurity(
                [],
                ['escape', 't'],
                ['path'],
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
