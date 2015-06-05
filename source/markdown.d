module markdown;

import std.string;

import vibe.core.file;
import vibe.inet.path;
import vibe.textfilter.markdown;

import types;

auto parseMarkdown(Path path, Settings settings)
{
    auto markdown = new Markdown;

    markdown.path = Path(chomp(chomp(path.toString(), ".md"), ".html"));

    markdown.sourcePath = settings.path ~ Path("markdown" ~ markdown.path.toString() ~ ".md");
    if (!existsFile(markdown.sourcePath))
        return null;

    markdown.content = filterMarkdown(readFileUTF8(markdown.sourcePath),
        MarkdownFlags.backtickCodeBlocks);

    return markdown;
}
