import os

# The AI routes are local-development only and mount just when this is set;
# the tests exercise them. test_ai_security checks they're off by default.
os.environ.setdefault("ENABLE_AI_ROUTES", "1")
