<?php

/**
 * @file plugins/generic/ojsbrJatsViewer/classes/JatsCache.php
 *
 * Copyright (c) 2026 OJSBR (https://ojsbr.com)
 * Distributed under the GNU GPL v3. For full terms see the file docs/COPYING.
 *
 * @class JatsCache
 *
 * @brief The HTML of each XML galley, kept in files so that a visit does not
 *        transform the XML again.
 *
 *        One file per galley holds every language. Its name carries a key made
 *        from everything the HTML depends on (the galley file and its images,
 *        the stylesheet, the address of the site), so a new file, a changed
 *        image or a new version of the plugin makes a new entry, and the old
 *        one is removed when the new one is written.
 */

namespace APP\plugins\generic\ojsbrJatsViewer\classes;

class JatsCache
{
    public function __construct(protected string $directory)
    {
    }

    public function file(int $galleyId, string $key): string
    {
        return $this->directory . '/' . $galleyId . '/' . preg_replace('/[^a-f0-9]/', '', $key) . '.json';
    }

    /**
     * @return array<string, mixed>|null
     */
    public function get(int $galleyId, string $key): ?array
    {
        $file = $this->file($galleyId, $key);
        if (!is_file($file)) {
            return null;
        }
        $data = json_decode((string) file_get_contents($file), true);
        return is_array($data) ? $data : null;
    }

    /**
     * Write the entry atomically and remove the older entries of the galley.
     *
     * @param array<string, mixed> $data
     */
    public function put(int $galleyId, string $key, array $data): bool
    {
        $file = $this->file($galleyId, $key);
        $directory = dirname($file);
        if (!is_dir($directory) && !mkdir($directory, 0755, true) && !is_dir($directory)) {
            return false;
        }

        $temporary = $file . '.' . getmypid() . '.tmp';
        $json = json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        if ($json === false || file_put_contents($temporary, $json) === false || !rename($temporary, $file)) {
            is_file($temporary) && unlink($temporary);
            return false;
        }

        foreach (glob($directory . '/*.json') ?: [] as $old) {
            if ($old !== $file) {
                unlink($old);
            }
        }

        return true;
    }

    public function clear(int $galleyId): void
    {
        $directory = $this->directory . '/' . $galleyId;
        foreach (glob($directory . '/*') ?: [] as $file) {
            unlink($file);
        }
        is_dir($directory) && rmdir($directory);
    }
}
