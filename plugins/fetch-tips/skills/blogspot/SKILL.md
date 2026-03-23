---
name: blogspot
description: Fetch Blogspot/Blogger content via JSON Feed API instead of scraping JS-rendered pages. Use when the user mentions a blogspot.com or blogger.com URL, wants to read or extract content from a Blogger site, asks to "fetch from blogspot", "scrape a blog", "get blog posts", or encounters empty/broken WebFetch results from *.blogspot.com pages.
---

# Blogspot / Blogger Fetch Strategy

Blogspot pages are JS-rendered — `WebFetch` on the HTML page returns an empty shell. Use the **Blogger JSON Feed API** instead.

## Feed URL Template

```
https://<blog>.blogspot.com/feeds/posts/default?alt=json&max-results=<n>
```

### Parameters

| Parameter        | Description                          | Example                          |
|------------------|--------------------------------------|----------------------------------|
| `alt=json`       | Return JSON instead of Atom XML      | Required                         |
| `max-results`    | Number of posts to return (max 150)  | `max-results=50`                 |
| `start-index`    | 1-based offset for pagination        | `start-index=51`                 |
| `published-min`  | Filter posts after this date (ISO)   | `published-min=2024-01-01T00:00:00` |
| `published-max`  | Filter posts before this date (ISO)  | `published-max=2024-12-31T23:59:59` |

## Examples

### Fetch latest 10 posts

```
WebFetch https://example.blogspot.com/feeds/posts/default?alt=json&max-results=10
```

### Fetch posts from a specific date range

```
WebFetch https://example.blogspot.com/feeds/posts/default?alt=json&max-results=50&published-min=2024-06-01T00:00:00&published-max=2024-06-30T23:59:59
```

### Paginate through all posts

First page:
```
WebFetch https://example.blogspot.com/feeds/posts/default?alt=json&max-results=50&start-index=1
```

Second page:
```
WebFetch https://example.blogspot.com/feeds/posts/default?alt=json&max-results=50&start-index=51
```

## Response Structure

The JSON response has this shape:

```
feed.entry[]        — array of posts
  .title.$t         — post title
  .content.$t       — full HTML content
  .published.$t     — publish date (ISO 8601)
  .updated.$t       — last updated date
  .author[].name.$t — author name
  .link[]            — links (look for rel="alternate" for the post URL)
```

## Key Points

- No headless browser needed — `WebFetch` alone is sufficient
- Works on any `*.blogspot.com` domain
- `max-results` caps at 150 per request; use `start-index` to paginate beyond that
- Date filters use ISO 8601 format
