<?php

/**
 * @file plugins/generic/ojsbrJatsViewer/tests/JatsCacheTest.php
 *
 * Copyright (c) 2026 OJSBR (https://ojsbr.com)
 * Distributed under the GNU GPL v3. For full terms see the file docs/COPYING.
 *
 * @class JatsCacheTest
 *
 * @brief The HTML kept for each galley. No database is needed.
 */

namespace APP\plugins\generic\ojsbrJatsViewer\tests;

use APP\plugins\generic\ojsbrJatsViewer\classes\JatsCache;
use PHPUnit\Framework\Attributes\CoversClass;
use PKP\tests\PKPTestCase;

#[CoversClass(JatsCache::class)]
class JatsCacheTest extends PKPTestCase
{
    protected string $dir;

    protected JatsCache $cache;

    protected function setUp(): void
    {
        parent::setUp();
        $this->dir = sys_get_temp_dir() . '/ojsbrJatsCacheTest' . getmypid();
        $this->cache = new JatsCache($this->dir);
    }

    protected function tearDown(): void
    {
        $this->cache->clear(1);
        $this->cache->clear(2);
        is_dir($this->dir) && rmdir($this->dir);
        parent::tearDown();
    }

    public function testAnEntryIsKeptUntilTheKeyChanges(): void
    {
        $this->assertNull($this->cache->get(1, sha1('a')));
        $this->assertTrue($this->cache->put(1, sha1('a'), ['languages' => ['pt'], 'parts' => ['pt' => ['article' => 'á']]]));
        $this->assertSame(['languages' => ['pt'], 'parts' => ['pt' => ['article' => 'á']]], $this->cache->get(1, sha1('a')));

        $this->cache->put(2, sha1('a'), ['other' => true]);
        $this->assertTrue($this->cache->put(1, sha1('b'), ['new' => true]));
        $this->assertNull($this->cache->get(1, sha1('a')), 'The old entry of the galley is removed.');
        $this->assertSame(['new' => true], $this->cache->get(1, sha1('b')));
        $this->assertSame(['other' => true], $this->cache->get(2, sha1('a')), 'Another galley is not touched.');
        $this->assertSame([], glob($this->dir . '/1/*.tmp'), 'No temporary file is left.');
    }

    public function testAKeyCannotLeaveTheDirectory(): void
    {
        $this->assertSame($this->dir . '/1/abc.json', $this->cache->file(1, '../../abc/x'));
    }
}
