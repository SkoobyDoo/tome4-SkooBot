#Contributing to SkooBot

#### Table Of Contents

[How Can I Contribute?](#how-can-i-contribute)
  * [Reporting Bugs](#reporting-bugs)
  * [Suggesting Enhancements](#suggesting-enhancements)
  * [Your First Code Contribution](#your-first-code-contribution)
  * [Pull Requests](#pull-requests)

[Style Guides](#style-guides)
* [Git Commit Messages](#git-commit-messages)
* [Code Style](#code-style)

## How Can I Contribute?

### Reporting Bugs
When you are creating a bug report, please include as many details as possible. Fill out [the required template](ISSUE_TEMPLATE.md), the information it asks for helps me resolve or respond to issues faster.

###Suggesting Enhancements
When you are creating an enhancement suggestion, please include as many details as possible. Fill in [the template](ISSUE_TEMPLATE.md), including the steps that you imagine you would take to test if the feature you're requesting existed.

###Your First Code Contribution
Unsure where to begin contributing to SkooBot? You can start by looking through the `beginner` and `help-wanted` issues:

* [Beginner issues][beginner] - issues which should only require a few lines of code, and a test or two.
* [Help wanted issues][help-wanted] - issues which should be a bit more involved than `beginner` issues. These should have resolution steps detailed in comments that need to be translated to code.

###Pull Requests
Please follow these steps to have your contribution considered by the maintainers:

1. Follow all instructions in [the template](PULL_REQUEST_TEMPLATE.md)
2. Follow the [styleguides](#styleguides)

While the prerequisites above must be satisfied prior to having your pull request reviewed, the reviewer may ask you to complete additional design work, tests, or other changes before your pull request can be ultimately accepted.

##Style Guides

###Git Commit Messages
* Use the present tense ("Add feature" not "Added feature")
* Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
* Limit the first line to 72 characters or less
* Reference issues and pull requests liberally after the first line

###Code Style
* Use spaces around operators
  *`count + 1` instead of `count+1`
* Use spaces after commas (unless separated by newlines)
* Use parentheses if it improves code clarity.
* Capitalize initialisms and acronyms in names, except for the first word, which should be lower-case:
  *`getURI` instead of `getUri`
  *`uriToOpen` instead of `URIToOpen`
