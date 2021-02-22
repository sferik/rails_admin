# RailsAdmin

[![Gem Version](https://img.shields.io/gem/v/rails_admin.svg)][gem]
[![Build Status](https://img.shields.io/github/workflow/status/sferik/rails_admin/Test)][ghactions]
[![Coverage Status](https://img.shields.io/coveralls/sferik/rails_admin.svg)][coveralls]
[![Inline docs](http://inch-ci.org/github/sferik/rails_admin.svg)][inch]
[![Code Climate](https://codeclimate.com/github/sferik/rails_admin.svg)][codeclimate]
[![SemVer](https://api.dependabot.com/badges/compatibility_score?dependency-name=rails_admin&package-manager=bundler&version-scheme=semver)][semver]

[gem]: https://rubygems.org/gems/rails_admin
[ghactions]: https://github.com/sferik/rails_admin/actions
[coveralls]: https://coveralls.io/r/sferik/rails_admin
[inch]: http://inch-ci.org/github/sferik/rails_admin
[codeclimate]: https://codeclimate.com/github/sferik/rails_admin
[semver]: https://dependabot.com/compatibility-score.html?dependency-name=rails_admin&package-manager=bundler&version-scheme=semver

RailsAdmin is a Rails engine that provides an easy-to-use interface for managing your data.

## Announcements

### [Action required] Security issue

**RailsAdmin 2.0.1, 2.0.0 and up to 1.4.2 have been reported to have XSS vulnerability.** We strongly recommend that you upgrade RailsAdmin to 2.0.2 (and higher) or 1.4.3 as soon as possible, if you are on those versions. See [d72090ec](https://github.com/sferik/rails_admin/commit/d72090ec6a07c3b9b7b48ab50f3d405f91ff4375) for the detail.

## Getting started

* Check out [the docs][docs].
* Try the [live demo][demo]. ([Source code][dummy_app])

[demo]: http://rails-admin-tb.herokuapp.com/
[dummy_app]: https://github.com/bbenezech/dummy_app
[docs]: https://github.com/sferik/rails_admin/wiki

## Features
* CRUD any data with ease
* Custom actions
* Automatic form validation
* Search and filtering
* Export data to CSV/JSON/XML
* Authentication (via [Devise](https://github.com/plataformatec/devise) or other)
* Authorization (via [CanCanCan](https://github.com/CanCanCommunity/cancancan) or [Pundit](https://github.com/elabs/pundit))
* User action history (via [PaperTrail](https://github.com/airblade/paper_trail))
* Supported ORMs
  * ActiveRecord
  * Mongoid



## Installation

1. On your gemfile: `gem 'rails_admin', '~> 2.0'`
2. Run `bundle install`
3. Run `rails g rails_admin:install`
4. Provide a namespace for the routes when asked
5. Start a server `rails s` and administer your data at [/admin](http://localhost:3000/admin). (if you chose default namespace: /admin)

## Configuration
### Global
In `config/initializers/rails_admin.rb`:

[Details](https://github.com/sferik/rails_admin/wiki/Base-configuration)

To begin with, you may be interested in setting up [Devise](https://github.com/sferik/rails_admin/wiki/Devise), [CanCanCan](https://github.com/sferik/rails_admin/wiki/Cancancan) or [Papertrail](https://github.com/sferik/rails_admin/wiki/Papertrail)!

### Per model
```ruby
class Ball < ActiveRecord::Base
  validates :name, presence: true
  belongs_to :player

  rails_admin do
    configure :player do
      label 'Owner of this ball: '
    end
  end
end
```

Details: [Models](https://github.com/sferik/rails_admin/wiki/Models), [Groups](https://github.com/sferik/rails_admin/wiki/Groups), [Fields](https://github.com/sferik/rails_admin/wiki/Fields)

## Support
If you have a question, please check this README, the wiki, and the [list of
known issues][troubleshoot].

[troubleshoot]: https://github.com/sferik/rails_admin/wiki/Troubleshoot

If you still have a question, you can ask the [official RailsAdmin mailing
list][list].

[list]: http://groups.google.com/group/rails_admin

If you think you found a bug in RailsAdmin, you can [submit an issue](https://github.com/sferik/rails_admin/issues/new).

## Supported Ruby Versions
This library aims to support and is [tested against][ghactions] the following Ruby implementations:

* Ruby 2.3
* Ruby 2.4
* Ruby 2.5
* Ruby 2.6
* Ruby 2.7
* [JRuby][]

[jruby]: http://jruby.org/
