-- Workflow: image processing pipeline with numeric parameters
-- Demonstrates numeric literals: integers, floats, negatives, and unit suffixes
resize(width: 1920, height: 1080)       -- ref: Bash("ffmpeg")
  >>> adjust(brightness: -0.3, contrast: 1.2)
  >>> compress(quality: 85)
  >>> watermark(opacity: 0.5, offset_x: -10, offset_y: -10)
  >>> upload(max_size: 500kb)           -- unit suffix on numeric literal
