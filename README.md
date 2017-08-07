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
require 'global_registry_bindings'
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
  def change
    add_column :people, :global_registry_id, :string, null: true, default: nil
    add_column :people, :global_registry_mdm_id, :string, null: true, default: nil
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

* `:binding`: Type of Global Registry binding. Either `:entity` or `:relationship`.
(default: `:entity`)
  
* `:id_column`: Column used to track the Global Registry ID for the model instance or relationship entity.
Can be a :string or :uuid column. (default: `:global_registry_id`) **[`:entity`, `:relationship`]**

* `:type`: Global Registry entity type. Accepts a Symbol or a Proc. Symbol is the name of the entity type, Proc
is passed the model instance and must return a symbol which is the entity type. Default value is underscored
name of the model. Ex: ```type: proc { |model| model.name.to_sym }```. When used in a `:relationship`, `:type`
is a unique name to identify the relationship. **[`:entity`, `:relationship`]**

* `:push_on`: Array of Active Record lifecycle events used to push changes to Global Registry.
(default: `[:create, :update, :destroy]`) **[`:entity`]**

* `:parent_association`: Name of the Active Record parent association. Must be defined before calling
global_registry_bindings in order to determine foreign_key for use in exclude_fields. Used to create a
hierarchy or to push child entity types. (Ex: person -> address) (default: `nil`) **[`:entity`]**

* `:parent_association_class`: Class name of the parent model. Required if `:parent_association` can not be used
to determine the parent class. This can happen if parent is defined by another gem, like `ancestry`.
(default: `nil`) **[`:entity`]**

* `:primary_binding`: Determines what type of global-registry-binding the primary association points to. Defaults
to `:entity`, but can be set to a `:relationship` type name (ex: `:assignment`) to create a relationship_type
between a relationship and an entity. (default: `:entity`) **[`:relationship`]**

* `:primary_association`: Name of the Active Record primary association. Must be defined before calling
global_registry_bindings in order to determine foreign_key for use in exclude_fields. (default: `nil`)
**[`:relationship`]**

* `:primary_association_class`: Class name of the primary model. Required if `:primary_association` can not be
used to determine the parent class. This can happen if parent is defined by another gem, like `ancestry`.
(default: `self.class`) **[`:relationship`]**

* `:primary_association_foreign_key`: Foreign Key column for the primary association. Used if foreign_key can
not be determined from `:primary_association`. (default: `:primary_association.foreign_key`)
**[`:relationship`]**

* `:related_association`: Name of the Active Record related association. Active Record association must be
defined before calling global_registry_bindings in order to determine the foreign key.
(default: `nil`) **[`:relationship`]**

* `:related_association_class`: Class name of the related model. Required if `:related_association` can not be
used to determine the related class. (default: `nil`) **[`:relationship`]**

* `:related_association_foreign_key`: Foreign Key column for the related association. Used if foreign_key can
not be determined from `:primary_association`. (default: `:primary_association.foreign_key`)
**[`:relationship`]**

* `:primary_relationship_name`: **Required** Name of primary relationship. Should be unique to prevent
ambiguous relationship names. (default: `nil`) **[`:relationship`]**

* `:related_relationship_name`: **Required** Name of the related relationship. Should be unique to prevent
ambiguous relationship names (default: `nil`) **[`:relationship`]**

* `:related_association_type`: Name of the related association entity_type. Required if unable to determined
`:type` from related. (default: `nil`) **[`:relationship`]**

* `:related_global_registry_id`: Global Registry ID of a remote related entity. Proc or Symbol. Implementation
should cache this as it may be requested multiple times. (default: `nil`) **[`:relationship`]**

* `:ensure_relationship_type`: Ensure Global Registry RelationshipType exists and is up to date.
(default: `true`) **[`:relationship`]**

* `:ensure_entity_type`: Ensure Global Registry Entity Type exists and is up to date.
(default: `true`) **[`:entity`]**

* `:client_integration_id`: Client Integration ID for relationship. Proc or Symbol.
(default: `:primary_association.id`) **[`:relationship`]**

* `:include_all_columns`: Include all model columns in the fields to push to Global Registry. If `false`, fields must
be defined in the `:extra_fields` option. (default: `true`)
**[`:entity`, `:relationship`]**

* `:exclude_fields`: Array, Proc or Symbol. Array of Model fields (as symbols) to exclude when pushing to Global
Registry. Array Will additionally include `:mdm_id_column` and `:parent_association` foreign key when defined.
If Proc, is passed type and model instance and should return an Array of the fields to exclude. If Symbol,
this should be a method name the Model instance responds to. It is passed the type and should return an Array
of fields to exclude. When Proc or Symbol are used, you must explicitly return the standard defaults.
(default:  `[:id, :created_at, :updated_at, :global_registry_id]`) **[`:entity`, `:relationship`]**

* `:extra_fields`: Additional fields to send to Global Registry. Hash, Proc or Symbol. As a Hash, names are the
keys and :type attributes are the values. Ex: `{language: :string}`. Name is a symbol and type is an
ActiveRecord column type. As a Proc, it is passed the type and model instance, and should return a Hash.
As a Symbol, the model should respond to this method, is passed the type, and should return a Hash.
**[`:entity`, `:relationship`]**

* `:mdm_id_column`: Column used to enable MDM tracking and set the name of the column. MDM is disabled when this
option is nil or empty. (default: `nil`) **[`:entity`]**

* `:mdm_timeout`: Only pull mdm information at most once every `:mdm_timeout`. (default: `1.minute`)
**[`:entity`]**

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
