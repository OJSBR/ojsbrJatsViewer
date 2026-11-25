<?php

/**
 * @file plugins/generic/ojsbrJatsViewer/classes/JatsRenderer.php
 *
 * Copyright (c) 2026 OJSBR (https://ojsbr.com)
 * Distributed under the GNU GPL v3. For full terms see the file docs/COPYING.
 *
 * @class JatsRenderer
 *
 * @brief Turns each language of a JATS article into HTML with the stylesheet
 *        of the plugin (xsl/jats2html.xsl).
 *
 *        The stylesheet runs with every file and network access forbidden and
 *        without PHP functions, so a document can only be turned into text.
 */

namespace APP\plugins\generic\ojsbrJatsViewer\classes;

use DOMDocument;
use DOMNode;
use DOMXPath;
use RuntimeException;
use XSLTProcessor;

class JatsRenderer
{
    /** Labels of the stylesheet (xsl:param l_*) and the locale keys of their text. */
    public const LABELS = [
        'l_abstract' => 'plugins.generic.ojsbrJatsViewer.label.abstract',
        'l_keywords' => 'plugins.generic.ojsbrJatsViewer.label.keywords',
        'l_references' => 'plugins.generic.ojsbrJatsViewer.label.references',
        'l_notes' => 'plugins.generic.ojsbrJatsViewer.label.notes',
        'l_acknowledgments' => 'plugins.generic.ojsbrJatsViewer.label.acknowledgments',
        'l_articleInfo' => 'plugins.generic.ojsbrJatsViewer.label.articleInfo',
        'l_aboutAuthors' => 'plugins.generic.ojsbrJatsViewer.label.aboutAuthors',
        'l_received' => 'plugins.generic.ojsbrJatsViewer.label.received',
        'l_revised' => 'plugins.generic.ojsbrJatsViewer.label.revised',
        'l_accepted' => 'plugins.generic.ojsbrJatsViewer.label.accepted',
        'l_published' => 'plugins.generic.ojsbrJatsViewer.label.published',
        'l_license' => 'plugins.generic.ojsbrJatsViewer.label.license',
        'l_copyright' => 'plugins.generic.ojsbrJatsViewer.label.copyright',
        'l_funding' => 'plugins.generic.ojsbrJatsViewer.label.funding',
        'l_correspondence' => 'plugins.generic.ojsbrJatsViewer.label.correspondence',
        'l_imageUnavailable' => 'plugins.generic.ojsbrJatsViewer.label.imageUnavailable',
        'l_orcid' => 'plugins.generic.ojsbrJatsViewer.label.orcid',
        'l_appendix' => 'plugins.generic.ojsbrJatsViewer.label.appendix',
    ];

    protected ?XSLTProcessor $processor = null;

    public function __construct(protected string $stylesheet)
    {
    }

    /**
     * Render one language of the article.
     *
     * @param array<string, string> $labels Text of each label of self::LABELS, in the language shown
     *
     * @return array{article: string, figures: string, tables: string, figureCount: int, tableCount: int}
     */
    public function render(JatsDocument $document, string $language, array $labels): array
    {
        $processor = $this->getProcessor();
        $processor->setParameter('', 'lang', $language);
        foreach (array_keys(self::LABELS) as $name) {
            $processor->setParameter('', $name, (string) ($labels[$name] ?? ''));
        }

        $result = $processor->transformToDoc($document->getDom());
        if (!$result instanceof DOMDocument) {
            throw new RuntimeException('The JATS stylesheet produced no document.');
        }

        $xpath = new DOMXPath($result);
        $article = $xpath->query('//*[@id="ojsbrJats-article"]')->item(0);
        if (!$article) {
            throw new RuntimeException('The JATS stylesheet produced no article.');
        }
        $figures = $xpath->query('//*[@id="ojsbrJats-figlist"]/li');
        $tables = $xpath->query('//*[@id="ojsbrJats-tablelist"]/li');

        return [
            'article' => $result->saveHTML($article),
            'figures' => $this->html($result, $figures),
            'tables' => $this->html($result, $tables),
            'figureCount' => $figures->length,
            'tableCount' => $tables->length,
        ];
    }

    /**
     * @param iterable<DOMNode> $nodes
     */
    protected function html(DOMDocument $document, iterable $nodes): string
    {
        $html = '';
        foreach ($nodes as $node) {
            $html .= $document->saveHTML($node);
        }
        return $html;
    }

    protected function getProcessor(): XSLTProcessor
    {
        if ($this->processor) {
            return $this->processor;
        }

        $stylesheet = new DOMDocument();
        if (!$stylesheet->load($this->stylesheet, LIBXML_NONET)) {
            throw new RuntimeException('The JATS stylesheet could not be read: ' . $this->stylesheet);
        }

        $processor = new XSLTProcessor();
        $processor->setSecurityPrefs(
            XSL_SECPREF_READ_FILE
            | XSL_SECPREF_WRITE_FILE
            | XSL_SECPREF_CREATE_DIRECTORY
            | XSL_SECPREF_READ_NETWORK
            | XSL_SECPREF_WRITE_NETWORK
        );
        $processor->importStylesheet($stylesheet);

        return $this->processor = $processor;
    }
}
