# Global Registry Bindings

Global Registry Bindings are a set of bindings to push ActiveRecord models to the Global Registry.


## Installation

Add to your Gemfile:
```ruby
gem 'global-registry-bindings'
```

Add a Global Registry initializer.
`config/initializers/global_registry.rb`
```ruby
require 'global_registry'
GlobalRegistry.configure do |config|
  config.access_token = ENV['GLOBAL_REGISTRY_TOKEN'] || 'fake'
  config.base_url = ENV['GLOBAL_REGISTRY_URL'] || 'https://backend.global-registry.org'
end
```

Make sure sidekiq is configured. See [Using Redis](https://github.com/mperham/sidekiq/wiki/Using-Redis) for information.

## Usage

To make use of `global-registry-bindings` your model will need a few additional columns.
To push models to Global Registry, you will need a `global_registry_id` column. You additionally need a
`global_registry_mdm_id` to pull a Global Registry MDM (master data model) id. These columns should be of type 
`:string` or `:uuid` and allow null values. Column names are customizable through options.
```ruby
class CreatePeople < ActiveRecord::Migration
  def self.up
    create_table :people do |t|
      t.string :name
      t.string :global_registry_id, :null => true, :index => true
      t.string :global_registry_mdm_id, :null => true, :index => true
    end
  end

  def self.down
    drop_table :people
  end
end
```

Enable `global-registry-bindings` functionality by declaring `global_registry_bindings` on your model.
```ruby
class Person < ActiveRecord::Base
  global_registry_bindings mdm_id_column: :global_registry_mdm_id
end
```

## Options

You can pass various options to the `global_registry_bindings` method. Configuration options are:

* `:id_column`: Column used to track the Global Registry ID for the model instance. Can be a :string or :uuid column.
(default: `:global_registry_id`) 
* `:mdm_id_column`: Column used to enable MDM tracking and set the name of the column. MDM is disabled when this
option is nil or empty. (default: `nil`)
* `:type`: Global Registry entity type. Default value is underscored name of the model.
* `:push_on`: Array of Active Record lifecycle events used to push changes to Global Registry.
(default: `[:create, :update, :delete]`) 
* `:parent_association`: Name of the Active Record parent association. Must be defined before calling
global_registry_bindings in order to determine foreign_key field. (default: `nil`)
* `:exclude_fields`: Model fields to exclude when pushing to Global Registry. Will additionally include `:mdm_id_column`
and `:parent_association` foreign key when defined. 
(default:  `[:id, :created_at, :updated_at, :global_registry_id]`)
* `:extra_fields`: Additional fields to send to Global Registry. This should be a hash with name as the key
and :type attributes as the value. Ex: `{language: :string}`. Name is a symbol and type is an ActiveRecord column type.
* `:mdm_timeout`: Only pull mdm information at most once every `:mdm_timeout`. (default: `1.minute`)

## Values for `extra_fields`

Values sent to Global Registry are calculated by sending the field `name` to the model. They can be overidden by
aliasing an existing method, adding a new method to the model or by overriding the `entity_attributes_to_push`
method. If a model does not respond to a name or raises a `NoMethodError`, the field will be omitted from the request.

```ruby
class Person < ActiveRecord::Base
  # Person has first_name, last_name and guid columns
  global_registry_bindings extra_fields: {full_name: :string, identity: :uuid, blargh: :integer},
                           exclude_fields: %i[guid]
  
  # Person doesn't respond to 'blargh' so it is omitted from the attributes to push
 
  alias_attribute :identity, :guid # Value for identity is aliased to guid
  
  # Value for full_name
  def full_name
    "#{first_name} #{last_name}"
  end
  
  # Override entity_attributes_to_push to add or modify fields and values
  def entity_attributes_to_push
    entity_attributes = super
    entity_attributes[:authentication] = { guid: guid }
    entity_attributes
  end
end
```

## Example Models

Example models can be found in the [specs](https://github.com/CruGlobal/global-registry-bindings/tree/master/spec/internal/app/models).
