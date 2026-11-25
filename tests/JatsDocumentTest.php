<?php

/**
 * @file plugins/generic/ojsbrJatsViewer/tests/JatsDocumentTest.php
 *
 * Copyright (c) 2026 OJSBR (https://ojsbr.com)
 * Distributed under the GNU GPL v3. For full terms see the file docs/COPYING.
 *
 * @class JatsDocumentTest
 *
 * @brief Reading a JATS file: languages, images and files that must be refused.
 */

namespace APP\plugins\generic\ojsbrJatsViewer\tests;

use APP\plugins\generic\ojsbrJatsViewer\classes\JatsDocument;
use PHPUnit\Framework\Attributes\CoversClass;
use PKP\tests\PKPTestCase;

#[CoversClass(JatsDocument::class)]
class JatsDocumentTest extends PKPTestCase
{
    protected function fixture(string $name): string
    {
        return file_get_contents(__DIR__ . '/fixtures/' . $name);
    }

    public function testTheLanguagesAreTheMainArticleAndItsTranslations(): void
    {
        $this->assertSame(['pt', 'en', 'es'], JatsDocument::fromString($this->fixture('trilingual.xml'))->getLanguages());
        $this->assertSame(['pt'], JatsDocument::fromString($this->fixture('tables-only.xml'))->getLanguages());
        $this->assertSame(['pt', 'en'], JatsDocument::fromString($this->fixture('figures.xml'))->getLanguages());
    }

    public function testAnArticleWithoutLanguageTakesTheLanguageOfTheSubmission(): void
    {
        $document = JatsDocument::fromString('<article><body><p>x</p></body></article>');

        $this->assertSame(['es'], $document->getLanguages('es'));
        $this->assertSame([''], $document->getLanguages());
    }

    public function testAFileThatIsNotAJatsArticleIsRefused(): void
    {
        $this->assertNull(JatsDocument::fromString($this->fixture('invalid.xml')), 'Not well-formed.');
        $this->assertNull(JatsDocument::fromString('<html><body/></html>'), 'Another root element.');
        $this->assertNull(JatsDocument::fromString('<x:article xmlns:x="urn:x"/>'), 'Another namespace.');
        $this->assertNull(JatsDocument::fromString(''));
    }

    public function testAnExternalEntityReadsNoFileOfTheServer(): void
    {
        $secret = tempnam(sys_get_temp_dir(), 'ojsbrJatsXxe');
        file_put_contents($secret, 'SECRET-' . getmypid());
        $xml = '<?xml version="1.0"?><!DOCTYPE article [<!ENTITY x SYSTEM "file://' . $secret . '">]>'
            . '<article xml:lang="pt"><body><p>[&x;]</p></body></article>';

        try {
            $document = JatsDocument::fromString($xml);
            $this->assertNotNull($document);
            $this->assertStringNotContainsString('SECRET-', $document->getDom()->saveXML());
        } finally {
            unlink($secret);
        }
    }

    public function testImagesPointToTheFilesOfTheGalley(): void
    {
        $document = JatsDocument::fromString($this->fixture('figures.xml'));
        $asked = [];
        $document->resolveFiles(function (string $href) use (&$asked): ?string {
            $asked[] = $href;
            return $href === 'fig-1.png' ? 'https://example.org/fig-1.png' : null;
        });

        $this->assertContains('fig-1.png', $asked);
        $this->assertContains('fig-2', $asked);
        $xpath = new \DOMXPath($document->getDom());
        $xpath->registerNamespace('xlink', JatsDocument::XLINK_NS);
        $this->assertSame(2, $xpath->query('//graphic[@' . JatsDocument::RESOLVED_ATTRIBUTE . '="https://example.org/fig-1.png"]')->length, 'Both languages use the image.');
        $this->assertSame(0, $xpath->query('//graphic[@xlink:href="nao-existe.tif"][@' . JatsDocument::RESOLVED_ATTRIBUTE . ']', null)->length);
    }

    public function testALanguageIsMatchedWithOrWithoutItsRegion(): void
    {
        $languages = ['pt', 'en', 'es'];

        $this->assertSame('en', JatsDocument::matchLanguage('en', $languages));
        $this->assertSame('pt', JatsDocument::matchLanguage('pt_BR', $languages));
        $this->assertSame('es', JatsDocument::matchLanguage('ES', $languages));
        $this->assertSame('pt-BR', JatsDocument::matchLanguage('pt_BR', ['en', 'pt-BR']));
        $this->assertNull(JatsDocument::matchLanguage('fr', $languages));
        $this->assertNull(JatsDocument::matchLanguage('', $languages));
        $this->assertNull(JatsDocument::matchLanguage(null, $languages));
    }
}
