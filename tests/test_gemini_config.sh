#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
config="${repo_root}/.gemini/config.yaml"

test -f "${config}" || { printf 'Missing %s\n' "${config}" >&2; exit 1; }
command -v ruby >/dev/null || { printf 'ruby is required to parse YAML\n' >&2; exit 1; }

ruby -ryaml -e '
path = ARGV[0]
begin
  cfg = YAML.safe_load(File.read(path))
rescue Psych::Exception => e
  abort "Invalid YAML in #{path}: #{e.message}"
end
abort "#{path} must contain a YAML mapping" unless cfg.is_a?(Hash)

errors = []
review = cfg["code_review"]
if review.is_a?(Hash)
  opened = review["pull_request_opened"]
  errors << "code_review.disable must be false" unless review["disable"] == false
  errors << "code_review.comment_severity_threshold must be MEDIUM" unless review["comment_severity_threshold"] == "MEDIUM"
  errors << "code_review.max_review_comments must be 15" unless review["max_review_comments"] == 15
  if opened.is_a?(Hash)
    errors << "pull_request_opened.summary must be true" unless opened["summary"] == true
    errors << "pull_request_opened.code_review must be true" unless opened["code_review"] == true
    errors << "pull_request_opened.include_drafts must be false" unless opened["include_drafts"] == false
  else
    errors << "code_review.pull_request_opened must be a mapping"
  end
else
  errors << "code_review must be a mapping"
end

errors << "have_fun must be false" unless cfg["have_fun"] == false

required = ["**/.env", "**/.env.*", "**/*.pem", "**/*.key", "**/node_modules/**", "**/dist/**"]
patterns = cfg["ignore_patterns"]
if patterns.is_a?(Array)
  missing = required - patterns
  errors << "ignore_patterns is missing: #{missing.join(", ")}" unless missing.empty?
else
  errors << "ignore_patterns must be a list"
end

unless errors.empty?
  warn "Invalid #{path}:"
  errors.each { |e| warn "  - #{e}" }
  exit 1
end
' "${config}"

printf 'Gemini config checks passed.\n'
