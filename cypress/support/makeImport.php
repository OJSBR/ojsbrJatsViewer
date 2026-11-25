<?php

/**
 * @file plugins/generic/ojsbrJatsViewer/cypress/support/makeImport.php
 *
 * Copyright (c) 2026 OJSBR (https://ojsbr.com)
 * Distributed under the GNU GPL v3. For full terms see the file docs/COPYING.
 *
 * Writes cypress/fixtures/import.xml: the articles of the browser tests, with
 * their XML galleys, in the native import format of OJS, for the data set of
 * PKP's continuous integration (journal publicknowledge, Vol. 1 No. 2 (2014)).
 *
 * Usage: php cypress/support/makeImport.php > cypress/fixtures/import.xml
 */

if (PHP_SAPI !== 'cli') {
    exit;
}

$fixtures = dirname(__DIR__, 2) . '/tests/fixtures';
$ns = 'http://pkp.sfu.ca';
$doc = new DOMDocument('1.0', 'utf-8');
$doc->formatOutput = true;
$root = $doc->appendChild($doc->createElementNS($ns, 'articles'));
$ids = ['file' => 100, 'submissionFile' => 100, 'author' => 100, 'galley' => 100];

$element = function (DOMNode $parent, string $name, ?string $text = null, array $attributes = []) use ($doc, $ns): DOMElement {
    $node = $doc->createElementNS($ns, $name);
    if ($text !== null) {
        $node->appendChild($doc->createTextNode($text));
    }
    foreach ($attributes as $key => $value) {
        $node->setAttribute($key, (string) $value);
    }
    return $parent->appendChild($node);
};

$file = function (DOMElement $article, string $path, string $stage, string $genre, ?int $parent = null) use ($element, &$ids): int {
    $id = ++$ids['submissionFile'];
    $fileId = ++$ids['file'];
    $submissionFile = $element($article, 'submission_file', null, ['id' => $id, 'file_id' => $fileId, 'stage' => $stage, 'genre' => $genre, 'uploader' => 'admin', 'viewable' => 'false']);
    $element($submissionFile, 'name', basename($path), ['locale' => 'en']);
    if ($parent) {
        $element($submissionFile, 'submission_file_ref', null, ['id' => $parent]);
    }
    $node = $element($submissionFile, 'file', null, ['id' => $fileId, 'filesize' => filesize($path), 'extension' => pathinfo($path, PATHINFO_EXTENSION)]);
    $element($node, 'embed', base64_encode(file_get_contents($path)), ['encoding' => 'base64']);
    return $id;
};

$articles = [
    ['JATS viewer: trilingual article', [['XML', 'trilingual.xml', []]]],
    ['JATS viewer: tables and no figure', [['XML', 'tables-only.xml', []]]],
    ['JATS viewer: figures and a table', [['XML', 'figures.xml', ['fig-1.png', 'fig-2.jpg']]]],
    ['JATS viewer: files that cannot be shown', [['Invalid XML', 'invalid.xml', []], ['XXE', 'xxe.xml', []]]],
];

foreach ($articles as $seq => [$title, $galleys]) {
    $article = $element($root, 'article', null, ['locale' => 'en', 'date_submitted' => '2026-11-25', 'status' => 3, 'submission_progress' => '', 'current_publication_id' => 1, 'stage' => 'production']);
    $galleyFiles = [];
    foreach ($galleys as [$label, $name, $images]) {
        $main = $file($article, "{$fixtures}/{$name}", 'proof', 'Article Text');
        foreach ($images as $image) {
            $file($article, "{$fixtures}/{$image}", 'dependent', 'Image', $main);
        }
        $galleyFiles[] = [$label, $main];
    }
    $publication = $element($article, 'publication', null, ['version' => 1, 'status' => 3, 'url_path' => '', 'seq' => $seq, 'access_status' => 0, 'date_published' => '2014-12-01', 'section_ref' => 'ART', 'primary_contact_id' => ++$ids['author']]);
    $element($publication, 'id', '1', ['type' => 'internal', 'advice' => 'ignore']);
    $element($publication, 'title', $title, ['locale' => 'en']);
    $author = $element($element($publication, 'authors'), 'author', null, ['include_in_browse' => 'true', 'user_group_ref' => 'Author', 'seq' => 0, 'id' => $ids['author']]);
    $element($author, 'givenname', 'Juliana', ['locale' => 'en']);
    $element($author, 'familyname', 'Pires', ['locale' => 'en']);
    $element($author, 'country', 'BR');
    $element($author, 'email', 'jpires@mailinator.com');
    foreach ($galleyFiles as $i => [$label, $ref]) {
        $galley = $element($publication, 'article_galley', null, ['locale' => 'en', 'approved' => 'true']);
        $element($galley, 'id', (string) ++$ids['galley'], ['type' => 'internal', 'advice' => 'ignore']);
        $element($galley, 'name', $label, ['locale' => 'en']);
        $element($galley, 'seq', (string) $i);
        $element($galley, 'submission_file_ref', null, ['id' => $ref]);
    }
    $issue = $element($publication, 'issue_identification');
    $element($issue, 'volume', '1');
    $element($issue, 'number', '2');
    $element($issue, 'year', '2014');
}

echo $doc->saveXML();
