# Butler

Butler is the generic DSL platform to allow user define their own DSL.

## Intention

There are so many DSL, good DSL already in production, like Vagrant, Rakefile etc. Why another one?

For so long the life for development, I sometimes wish to just can reduce the repetitive work that I've come across into specific standard script. However I find that I'm reinventing the code again and again. Issue is that each project has different repetitive work and not really same but carry similarity between them. Like how to release a software, one project may choose to push to multiple repositories but the other only push to specific repository and tag at the same time.

Most of the DSL carries a specific purpose, like Vagrant is to provisioning and managing VM for development/testing/production. One might think Rakefile is great for generic purpose but for my initial purpose, like to consolidate the git command into single command (try run > butler -e "git :commit" for example), is not that easy. Furthermore, using Rakefile likely I will have to hardcode the git in the file, which may not be cross platform viable since my git may be hosted in /usr/bin but yours could be in /opt/git/bin.

Butler intended to be just a faithful helper that could condense or structure the day to day commandline operations into a single file that can be run on multiple platforms and future proving.

## Installation

From your ruby runtime, you just run

```ruby
gem install butler
```
to have the butler install into your environment. 

Note the butler is meant to be command line program like rake, rails.

## Usage

The butler is looking for .job file to execute. 

So first step is to create a job file.

Sample job file can be like:

```ruby
job :rebuild do
  ver = prompt "Please provide version for this release:", required: true
  set :releasing_version, ver   # this is global value. use get() anywhere to get the value out.
  
  include_job :uninstall_butler
  include_job :build_gem 
  include_job :install_gem
  include_job :check_in
end

job :uninstall_butler do
  rubygems :uninstall, "butler"
  # Following same effect as above
  #rubygem do
  #  uninstall "butler"
  #end
end

job :build_gem do
  rubygems :build, 'butler.gemspec'
  # Following same effect as above
  #rubygem do
  #  build 'butler.gemspec'
  #end
end

job :install_gem do
  rubygems :install, 'butler'
  # Following same effect as above
  #rubygem do
  #  install 'butler'
  #end
end

job :check_in do
  git :commit
  git :push, "origin" #,"master"
  git :tag
  git :push_tag, "origin"
  # Following same effect as above
  #git do
  #  commit
  #  push "origin" #,"master"
  #  tag
  #  push_tag "origin"
  #end
end

```

```sh
> butler sample.job
```
running butler with this job file will prompt you which job you want to execute

Or immediately ask butler to execute a job

```sh
> butler sample.job check_in
```
Shall execute the job :check_in


## Online Help

User can run the following command to get simple help on the DSL:

```sh
> butler -e "git :assist"
```
The above shall print out how to use the DSL for git.

```sh
> butler -e "rubygem :assist"
```
The above shall print out how to use the DSL for rubygem

If you create an extension as following section, you should implement the method assist() to assist user.


## Extension

Currently the butler only support limited 'git' and 'rubygem' functions, just to suit my need.
However butler is designed to be extensible by the developer on the ground, anytime.

For example if you want to add new DSL 'rails', you can do the following:
1. Create directory 'butler/handler' in the root folder of the project
2. Create a class with name represent the DSL you want to defined, inside module Butler. For example if you want to create dsl 'rails', your class must named "Rail" (this is the output of ActiveSupport classify function)
3. Inherit this class from Butler::CliApp for some helper functions included.
Example:
```ruby
require 'butler'

module Butler
  class Rail < CliApp
    def initialize(args, &block)
      super
      # additional setup
    end

    # any methods here shall be part of the dsl
    # for example let's have a method db_setup()
    def db_setup(args)
      # call rails db:create
      # call rails db:migrate
      # setup initial default data
      # etc etc etc
    end

    def assist
      # print usage to assist developer
    end
  end
end
```

in anyname.job file, you can use the DSL like this:

```ruby
job :pre_production do
  rails :db_setup, "name"
  # or
  rails do
    db_setup "name"
  end
end
```

to trigger your DSL. Butler shall load everything inside the butler/handler directory


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/chrisliaw/butler.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
