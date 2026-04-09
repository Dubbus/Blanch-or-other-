"""
Instagram caption scraper scaffold.

TODO: Implement actual scraping via Instagram API or third-party service.
For now, this module defines the interface that the pipeline will use.
"""


def scrape_captions(handle: str, *, limit: int = 50) -> list[dict]:
    """
    Scrape recent captions from an Instagram account.

    Args:
        handle: Instagram handle (e.g., "@sydneychambers")
        limit: Max number of posts to scrape

    Returns:
        List of dicts with 'text', 'url', 'timestamp', 'type' (caption/story)
    """
    # TODO: Implement with Instagram Basic Display API or scraping service
    raise NotImplementedError(
        f"Instagram scraping not yet implemented for {handle}. "
        "Use seed data for initial development."
    )
