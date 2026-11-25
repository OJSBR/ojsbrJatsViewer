<?php

/**
 * @file plugins/generic/ojsbrJatsViewer/classes/JatsDocument.php
 *
 * Copyright (c) 2026 OJSBR (https://ojsbr.com)
 * Distributed under the GNU GPL v3. For full terms see the file docs/COPYING.
 *
 * @class JatsDocument
 *
 * @brief A JATS article read from an XML file sent by a third party: the
 *        languages it is written in and the images it refers to.
 *
 *        The file is parsed without network access, without loading the DTD
 *        and without replacing entities, so an XML external entity (XXE) can
 *        neither read a file of the server nor call another server.
 */

namespace APP\plugins\generic\ojsbrJatsViewer\classes;

use DOMDocument;
use DOMElement;
use DOMXPath;

class JatsDocument
{
    public const XLINK_NS = 'http://www.w3.org/1999/xlink';

    /** Attribute where the plugin writes the address of an image found among the files of the galley. */
    public const RESOLVED_ATTRIBUTE = 'data-ojsbr-src';

    protected function __construct(protected DOMDocument $dom)
    {
    }

    /**
     * Parse a JATS article. Returns null when the file is not well-formed XML
     * or its root element is not <article>.
     */
    public static function fromString(string $xml): ?self
    {
        if (trim($xml) === '') {
            return null;
        }

        $previousErrors = libxml_use_internal_errors(true);
        $previousLoader = libxml_get_external_entity_loader();
        // Belt and braces: even if some flag asked for it, no external resource is loaded.
        libxml_set_external_entity_loader(static fn () => null);
        try {
            $dom = new DOMDocument();
            $loaded = $dom->loadXML($xml, LIBXML_NONET | LIBXML_COMPACT);
        } finally {
            libxml_set_external_entity_loader($previousLoader);
            libxml_clear_errors();
            libxml_use_internal_errors($previousErrors);
        }

        if (!$loaded || $dom->documentElement?->localName !== 'article' || $dom->documentElement->namespaceURI !== null) {
            return null;
        }

        return new self($dom);
    }

    public function getDom(): DOMDocument
    {
        return $this->dom;
    }

    /**
     * Language of the main article, as written in the XML (empty if missing).
     */
    public function getMainLanguage(): string
    {
        return trim($this->dom->documentElement->getAttribute('xml:lang'));
    }

    /**
     * Languages of the text: the main article first, then each translation
     * (<sub-article article-type="translation" xml:lang="...">).
     *
     * @param string $default Language of the main article when the XML does not say it
     *
     * @return string[]
     */
    public function getLanguages(string $default = ''): array
    {
        $languages = [$this->getMainLanguage() ?: $default];
        $xpath = new DOMXPath($this->dom);
        foreach ($xpath->query('/article/sub-article[@article-type="translation"][@xml:lang]') as $subArticle) {
            /** @var DOMElement $subArticle */
            $languages[] = trim($subArticle->getAttribute('xml:lang'));
        }

        $languages = array_values(array_unique(array_filter($languages, static fn (string $language) => $language !== '')));
        // Still unknown: one language, without a name.
        return $languages ?: [''];
    }

    /**
     * Point every image and supplementary file to the address of a file of the
     * galley. The resolver receives the name written in the XML and returns the
     * address, or null when no file of the galley has that name.
     *
     * @param callable(string): ?string $resolver
     */
    public function resolveFiles(callable $resolver): void
    {
        $xpath = new DOMXPath($this->dom);
        $xpath->registerNamespace('xlink', self::XLINK_NS);
        foreach ($xpath->query('//*[@xlink:href][self::graphic or self::inline-graphic or self::media or self::supplementary-material or self::inline-supplementary-material]') as $element) {
            /** @var DOMElement $element */
            $url = $resolver(trim($element->getAttributeNS(self::XLINK_NS, 'href')));
            if ($url !== null) {
                $element->setAttribute(self::RESOLVED_ATTRIBUTE, $url);
            }
        }
    }

    /**
     * Find, among the languages of the text, the one that matches a language
     * or locale code (pt, pt-BR, pt_BR...): the same code first, then the same
     * language without the region.
     *
     * @param string[] $languages
     */
    public static function matchLanguage(?string $code, array $languages): ?string
    {
        $wanted = self::normalize((string) $code);
        if ($wanted === '') {
            return null;
        }
        foreach ($languages as $language) {
            if (self::normalize($language) === $wanted) {
                return $language;
            }
        }
        $primary = strtok($wanted, '-');
        foreach ($languages as $language) {
            if (strtok(self::normalize($language), '-') === $primary) {
                return $language;
            }
        }

        return null;
    }

    protected static function normalize(string $code): string
    {
        return strtolower(str_replace(['_', '@'], ['-', '-'], trim($code)));
    }
}
