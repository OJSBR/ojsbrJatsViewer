<?php

/**
 * @file plugins/generic/ojsbrJatsViewer/tests/JatsRendererTest.php
 *
 * Copyright (c) 2026 OJSBR (https://ojsbr.com)
 * Distributed under the GNU GPL v3. For full terms see the file docs/COPYING.
 *
 * @class JatsRendererTest
 *
 * @brief The HTML of each language, the figure and table panels, and what the
 *        stylesheet must never let through.
 */

namespace APP\plugins\generic\ojsbrJatsViewer\tests;

use APP\plugins\generic\ojsbrJatsViewer\classes\JatsDocument;
use APP\plugins\generic\ojsbrJatsViewer\classes\JatsRenderer;
use PHPUnit\Framework\Attributes\CoversClass;
use PKP\tests\PKPTestCase;
use RuntimeException;

#[CoversClass(JatsRenderer::class)]
class JatsRendererTest extends PKPTestCase
{
    protected JatsRenderer $renderer;

    protected function setUp(): void
    {
        parent::setUp();
        $this->renderer = new JatsRenderer(dirname(__DIR__) . '/xsl/jats2html.xsl');
    }

    protected function render(string $fixture, string $language, array $labels = []): array
    {
        $document = JatsDocument::fromString(file_get_contents(__DIR__ . '/fixtures/' . $fixture));
        return $this->renderer->render($document, $language, $labels + ['l_references' => 'REFERENCES-LABEL']);
    }

    protected function text(string $html): string
    {
        return html_entity_decode(strip_tags($html), ENT_QUOTES | ENT_HTML5, 'UTF-8');
    }

    public function testEachLanguageShowsItsOwnText(): void
    {
        $pt = $this->render('trilingual.xml', 'pt');
        $en = $this->render('trilingual.xml', 'en');
        $es = $this->render('trilingual.xml', 'es');

        $this->assertStringContainsString('A deferência como premissa para soluções estruturais', $this->text($pt['article']));
        $this->assertStringContainsString('Deference as a premise to structural solutions', $this->text($en['article']));
        $this->assertStringContainsString('La deferencia como premisa para las soluciones estructurales', $this->text($es['article']));

        $this->assertStringContainsString('lang="en"', $en['article']);
        $this->assertStringContainsString('Final considerations', $en['article']);
        $this->assertStringNotContainsString('Considerações finais', $en['article'], 'The English page has no Portuguese section.');
        $this->assertStringNotContainsString('Final considerations', $pt['article'], 'The Portuguese page has no English section.');
    }

    public function testATranslationWithoutReferencesShowsThoseOfTheMainArticle(): void
    {
        $en = $this->render('trilingual.xml', 'en');

        $this->assertStringContainsString('<h2>REFERENCES-LABEL</h2>', $en['article'], 'Heading in the language of the page, not the Portuguese one.');
        $this->assertStringContainsString('id="j-B6"', $en['article']);
        $this->assertStringContainsString('href="#j-B6"', $en['article'], 'Citations link to the references.');
    }

    public function testAnArticleWithTablesAndNoFigureHasOnlyTheTablesPanel(): void
    {
        $part = $this->render('tables-only.xml', 'pt');

        $this->assertSame(0, $part['figureCount']);
        $this->assertSame(2, $part['tableCount']);
        $this->assertStringContainsString('href="#j-t1"', $part['tables']);
        $this->assertStringContainsString('Taxa de evasão por ano de ingresso', $part['tables']);
        $this->assertStringContainsString('id="j-t1"', $part['article'], 'The panel entry has a target.');
        $this->assertStringContainsString('colspan="2"', $part['article']);
        $this->assertStringContainsString('rowspan="2"', $part['article']);
    }

    public function testFiguresUseTheFilesOfTheGalley(): void
    {
        $document = JatsDocument::fromString(file_get_contents(__DIR__ . '/fixtures/figures.xml'));
        $document->resolveFiles(fn (string $href) => in_array($href, ['fig-1.png', 'fig-2', 'fig-2.jpg']) ? 'https://example.org/f/' . $href : null);
        $pt = $this->renderer->render($document, 'pt', ['l_imageUnavailable' => 'NO-IMAGE']);

        $this->assertSame(3, $pt['figureCount']);
        $this->assertSame(1, $pt['tableCount']);
        $this->assertStringContainsString('src="https://example.org/f/fig-1.png"', $pt['article']);
        $this->assertStringContainsString('src="https://example.org/f/fig-2"', $pt['article'], 'The first image of <alternatives>.');
        $this->assertStringContainsString('NO-IMAGE', $pt['article'], 'A figure without its file says so.');
        $this->assertStringContainsString('class="ojsbrJats-thumb"', $pt['figures']);

        $en = $this->renderer->render($document, 'en', []);
        $this->assertStringContainsString('Average grades by class', $en['figures']);
        $this->assertStringContainsString('href="#j-f1-en"', $en['figures']);
    }

    public function testTheSingleLanguageArticleShowsItsOtherAbstracts(): void
    {
        $part = $this->render('tables-only.xml', 'pt');

        $this->assertStringContainsString('<section class="ojsbrJats-abstract" lang="en">', $part['article']);
        $this->assertStringContainsString('dropout; distance education', $part['article']);
        $this->assertStringContainsString('<math display="block">', $part['article'], 'MathML is kept.');
        $this->assertStringContainsString('https://doi.org/10.1590/S0104-40362014000200008', $part['article']);
        $this->assertStringContainsString('https://doi.org/10.5555/teste.2025.1', $part['article'], 'DOI of a structured citation.');
        $this->assertStringContainsString('https://orcid.org/0000-0002-1825-0097', $part['article']);
        $this->assertStringContainsString('2026-05-02', $part['article'], 'Dates in ISO 8601.');
        $this->assertStringContainsString('Universidade Exemplo, Brasília, DF, Brasil', $this->text($part['article']), 'Affiliation with the punctuation of the XML.');
    }

    public function testNothingDangerousGetsThrough(): void
    {
        $part = $this->render('xxe.xml', 'pt');
        $html = $part['article'];

        $this->assertStringNotContainsString('javascript:', $html);
        $this->assertStringNotContainsString('data:text', $html);
        $this->assertStringNotContainsString('<script', $html);
        $this->assertStringNotContainsString('onclick', $html);
        $this->assertStringNotContainsString('root:x:0:0:', $html);
        $this->assertStringContainsString('mathvariant="bold"', $html, 'Presentation attributes of MathML are kept.');

        $tables = $this->render('tables-only.xml', 'pt')['article'];
        $this->assertStringContainsString('href="https://ojsbr.com"', $tables);
        $this->assertStringNotContainsString('javascript:', $tables);
    }

    public function testTheStylesheetCannotReadFiles(): void
    {
        $stylesheet = tempnam(sys_get_temp_dir(), 'ojsbrJatsXsl');
        $secret = tempnam(sys_get_temp_dir(), 'ojsbrJatsSecret');
        file_put_contents($secret, '<x>SECRET</x>');
        file_put_contents($stylesheet, '<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">'
            . '<xsl:template match="/"><div><article id="ojsbrJats-article"><xsl:value-of select="document(\'' . $secret . '\')"/></article></div></xsl:template></xsl:stylesheet>');

        try {
            $renderer = new JatsRenderer($stylesheet);
            $read = null;
            try {
                $read = @$renderer->render(JatsDocument::fromString('<article/>'), '', [])['article'];
            } catch (RuntimeException $e) {
                // The transformation is refused: nothing is shown.
            }
            $this->assertStringNotContainsString('SECRET', (string) $read);
        } finally {
            unlink($stylesheet);
            unlink($secret);
        }
    }

    public function testRenderingIsFast(): void
    {
        $start = microtime(true);
        foreach (['pt', 'en', 'es'] as $language) {
            $this->render('trilingual.xml', $language);
        }
        $this->assertLessThan(2, microtime(true) - $start);
    }
}
