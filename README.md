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

### Additional Configuration

#### Sidekiq options
The `global-registry-bindings` gem allows for configuring default sidekiq options for all workers. You can configure
this by creating a custom initializer, or adding to the global_registry initializer the following.
```ruby
GlobalRegistry::Bindings.configure do |config|
  # Run global-registry-bindings workers in a :custom queue
  config.sidekiq_options = { queue: :custom }
end
```
Custom sidekiq options will apply to all Global Registry Bindings sidekiq Workers.

#### Redis Error Action
This option defines what `global-registry-bindings` does when a Redis error is encountered while adding a sidekiq
worker to the queue. Valid actions are `:ignore`, `:log` and `:raise`.
```ruby
GlobalRegistry::Bindings.configure do |config|
  config.redis_error_action = :ignore # Silently ignore redis issues
end
```
The default behaviour is to `:log` the error to `Rollbar` if present.

## Usage

To make use of `global-registry-bindings` your model will need a few additional columns.
To push models to Global Registry, you will need a `global_registry_id` column. You additionally need a
`global_registry_mdm_id` to pull a Global Registry MDM (master data model) id. Additionally, relationships will also
require columns to track relationship ids. These columns should be of type 
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

You can pass various options to the `global_registry_bindings` method. Options will list whether they are valid for
`:entity`, `:relationship` or both bindings. 

* `:binding`: Type of Global Registry binding. Either `:entity` or `:relationship`.
(default: `:entity`)

* `:id_column`: Column used to track the Global Registry ID for the entity or relationship entity.
Can be a `:string` or `:uuid` column. (default: `:global_registry_id`) **[`:entity`, `:relationship`]**

* `:type`: Global Registry Entity Type name. This name should be unique in Global Registry or point to an existing
Entity Type.  When used in a `:relationship` binding, it is required to be unique across all relationships on this
ActiveRecord class. Accepts a Symbol or a Proc. Symbol is the name of the Entity Type, Proc
is passed the model instance and must return a symbol which is the Entity Type. Defaults to the underscored
name of the class. Ex: ```type: proc { |model| model.name.to_sym }```. **[`:entity`, `:relationship`]**

* `:push_on`: Array of Active Record lifecycle events used to push changes to Global Registry.
(default: `[:create, :update, :destroy]`) **[`:entity`]**

* `:parent`: Name of the Active Record parent association (`:belongs_to`, `:has_one` ...). Must be defined
before calling `global_registry_bindings` in order to determine foreign_key for use in exclude. Used to create a
hierarchy or to push child entity types. (Ex: person -> address) (default: `nil`) **[`:entity`]**

* `:parent_class`: Active Record Class name of the parent. Required if `:parent` can not be used
to determine the parent class. This can happen if parent is defined by another gem, like `ancestry`.
(default: `nil`) **[`:entity`]**

* `:primary_binding`: Determines what type of global-registry-binding the primary association points to. Defaults
to `:entity`, but can be set to a `:relationship` type (ex: `:assignment`) to create a relationship_type
between a relationship and an entity. (default: `:entity`) **[`:relationship`]**

* `:primary`: Name of the Active Record primary association. Must be defined before calling
global_registry_bindings in order to determine foreign_key for use in exclude. If missing, `:primary` is assumed to be
the current Active Record model. (default: `nil`) **[`:relationship`]**

* `:primary_class`: Class name of the primary model. Required if `:primary` can not be
used to determine the primary class. This can happen if parent is defined by another gem, like `ancestry`.
(default: `self.class`) **[`:relationship`]**

* `:primary_foreign_key`: Foreign Key column for the primary association. Used if foreign_key can
not be determined from `:primary`. (default: `:primary.foreign_key`) **[`:relationship`]**

* `:primary_name`: **Required** Name of primary relationship (Global Registry relationship1). Should be unique
to prevent ambiguous relationship names. (default: `nil`) **[`:relationship`]**

* `:related`: Name of the Active Record related association. Active Record association must be
defined before calling global_registry_bindings in order to determine the foreign key.
(default: `nil`) **[`:relationship`]**

* `:related_class`: Class name of the related model. Required if `:related_association` can not be
used to determine the related class. (default: `nil`) **[`:relationship`]**

* `:related_foreign_key`: Foreign Key column for the related association. Used if foreign_key can
not be determined from `:related`. (default: `:related.foreign_key`) **[`:relationship`]**

* `:related_name`: **Required** Name of the related relationship (Global Registry relationship2). Should be
unique to prevent ambiguous relationship names (default: `nil`) **[`:relationship`]**

* `:related_type`: Name of the related association Entity Type. Required if unable to determined
`:type` from related. (default: `nil`) **[`:relationship`]**

* `:related_global_registry_id`: Global Registry ID of a remote related entity. Proc or Symbol. Implementation
should cache this as it may be requested multiple times. (default: `nil`) **[`:relationship`]**

* `:ensure_type`: Ensure Global Registry Entity Type or Relationship Entity Type exists and is up to date.
(default: `true`) **[`:entity`, `:relationship`]**

* `:client_integration_id`: Client Integration ID for relationship. Proc or Symbol.
(default: `:primary.id`) **[`:relationship`]**

* `:include_all_columns`: Include all model columns in the fields to push to Global Registry. If `false`, fields must
be defined in the `:fields` option. (default: `false`) **[`:entity`, `:relationship`]**

* `:exclude`: Array, Proc or Symbol. Array of Model fields (as symbols) to exclude when pushing to Global
Registry. Array Will additionally include `:mdm_id_column` and `:parent_association` foreign key when defined.
If Proc, is passed type and model instance and should return an Array of the fields to exclude. If Symbol,
this should be a method name the Model instance responds to. It is passed the type and should return an Array
of fields to exclude. When Proc or Symbol are used, you must explicitly return the standard defaults.
(default:  `[:id, :created_at, :updated_at, :global_registry_id]`) **[`:entity`, `:relationship`]**

* `:fields`: Additional fields to send to Global Registry. Hash, Proc or Symbol. As a Hash, names are the
keys and :type attributes are the values. Ex: `{language: :string}`. Name is a symbol and type is an
ActiveRecord column type. As a Proc, it is passed the type and model instance, and should return a Hash.
As a Symbol, the model should respond to this method, is passed the type, and should return a Hash.
**[`:entity`, `:relationship`]**

* `:mdm_id_column`: Column used to enable MDM tracking and set the name of the column. MDM is disabled when this
option is nil or empty. (default: `nil`) **[`:entity`]**

* `:mdm_timeout`: Only pull mdm information at most once every `:mdm_timeout`. (default: `1.minute`)
**[`:entity`]**

* `:if`, `:unless`: Proc or Symbol, called to determine if the change should be sent (enqueue a worker) to Global
Registry. Proc and Symbol will both receive the model for an entity, and the type and model for a relationship. See
[Conditional Push](#conditional-push) for examples. **[`:entity`, `:relationship`]**

## Entities

`global-registry-bindings` default bindings is to push an Active Record class as an Entity to Global Registry.
This can be used to push root level entities, entities with a parent and entities with a hierarchy. You can also
enable fetching of a Master Data Model from Global Registry.

See [About Entities](https://github.com/CruGlobal/global_registry_docs/wiki/About-Entities) for more
information on Global Registry Entities.

### Root Entity
```ruby
class Person < ActiveRecord::Base
  global_registry_bindings mdm_id_column: :global_registry_mdm_id
end
```
This will push the Person Active Record model to Global Registry as a `person` Entity Type, storing the resulting id
value in the `global_registry_id` column, as well as fetching a `master_person` Entity and storing it in the
`global_registry_mdm_id` column.

### Parent/Child Entity
```ruby
class Person < ActiveRecord::Base
  has_many :addresses, inverse_of: :person
  global_registry_bindings
end
 
class Address < ActiveRecord::Base
  belongs_to :person
  global_registry_bindings
end
```
This will push the Person model to Global Registry as a `person` Entity Type, and the Address model as an `address`
Entity Type that has a parent of `person`.

### Entity Hierarchy
```ruby
class Ministry < ActiveRecord::Base
  has_many :children, class_name: 'Ministry', foreign_key: :parent_id
  belongs_to :parent, class_name: 'Ministry'
  
  global_registry_bindings parent: :parent
end
```
This will push the Ministry model to Global Registry as well as the parent/child hierarchy. Global Registry only allows
a single parent, and does not allow circular references. Hierarchy is also EntityType specific, and not saved per
system in Global Registry, meaning, the last system to push a parent wins (You can accidently override another systems
hierarchy. This should be avoided and instead pushed as a relationship if needed).

## Relationships

`global-registry-bindings` can also be configured to push relationships between models to Global Registry. All
relationships in Global Registry are many to many, but by using Active Record associations, we can simulate one to many
and one to one.

See [About Relationships](https://github.com/CruGlobal/global_registry_docs/wiki/About-Relationships) for more
information on Global Registry relationships.

### Many-to-Many with join model
```ruby
class Ministry < ActiveRecord::Base
  has_many :assignments
  has_many :people, through: :assignments
  global_registry_bindings
end
 
class Person < ActiveRecord::Base
  has_many :assignments
  has_many :ministries, through: :assignments
  global_registry_bindings
end
 
class Assignment < ActiveRecord::Base
  belongs_to :person
  belongs_to :ministry
  global_registry_bindings binding: :relationship,
                           primary: :person,
                           primary_name: :people,
                           related: :ministry,
                           related_name: :ministries
end
```
This will push Ministry and Person to Global Registry as Entities, and Assignment join model as a relationship between
them, storing the relationship id in the Assignment `global_registry_id` column.

### One-to-Many
```ruby
class Person < ActiveRecord::Base
  has_many :pets
  global_registry_bindings
end
 
class Pet < ActiveRecord::Base
  belongs_to :person
  global_registry_bindings binding: :relationship,
                           type: :owner,
                           related: :person
end
```

## Fields and Values

Both Entities and Relationships include fields that will be pushed to Global Registry.

### Fields

The fields that are pushed to Global Registry are defined with a combination of the `:fields`, `:exclude` and
`:include_all_columns` options. The `:fields` option defines the fields and field types to be pushed. If
`:include_all_columns` is set to `true`,`:fields` are appended to the list of all model columns. `:exclude` option is
then used to remove fields from the list. If `:ensure_type` is `true`, the Global Registry EntityType or
RelationshipType will be updated when new fields are defined. If `:ensure_type` is false, and fields are missing
from the EntityType or RelationshipType, Global Registry will throw an error. It is the developers job to ensure Global
Registry Entity and Relationship Types are accurate when `:ensure_type` is disabled.

Given an Active Record model:
```ruby
create_table :products do |t|
  t.string :name
  t.text :description
  t.string :global_registry_id
  t.references :supplier, index: true, foreign_key: true
  t.string :supplier_gr_rel_id, null: true, default: nil
  t.timestamps null: false
end
```
And the following `global_registry_bindings`:
```ruby
class Product < ActiveRecord::Base
  belongs_to :supplier
  global_registry_bindings fields: { name: string, description: :text }
end
```
Will result in the following fields `{:name=>:string, :description=>:text}`

```ruby
class Product < ActiveRecord::Base
  belongs_to :supplier
  global_registry_bindings include_all_columns: true,
                           exclude: %i[supplier_id]
end
```
Will result in the following fields `{:name=>:string, :description=>:text}`, `:id`, `:global_registry_id` and timestamp
fields are excluded by default when `:include_all_columns` is `true`.

You can add additional fields by specifying them in the `:fields` option.
```ruby
class Product < ActiveRecord::Base
  belongs_to :supplier
  global_registry_bindings include_all_columns: true,
                           exclude: %i[supplier_id],
                           fields: {color: :string}
end
```
Will result in the following fields `{:name=>:string, :description=>:text, :color=>:string}`

Relationships can also include fields:
```ruby
class Product < ActiveRecord::Base
  belongs_to :supplier
  global_registry_bindings fields: { name: string, description: :text }
  global_registry_bindings binding: :relationship,
                           type: :supplier,
                           related: :supplier,
                           id_column: :supplier_gr_rel_id,
                           extra: {quantity: :integer}
end
```
Will result in the following fields `{:quantity=>:integer}`

`:fields` and `:exclude` can also be defined as a proc, labmda or symbol. Symbol must point to a method that will
return either the extra or excluded fields.
```ruby
class Product < ActiveRecord::Base
  belongs_to :supplier
  global_registry_bindings include_all_columns: true,
                           exclude: ->(type, model) { model.name == 'Sprocket' ? [] : %i[:field1] },
                           fields: :extra_fields
  def extra_fields(type)
    # type === :product
    {field1: :string, field2: :boolean}
  end
end
```

You can debug the current fields that will be pushed using the rails console:
```ruby
irb> Product.first.entity_columns_to_push
=> {:name=>:string, :description=>:text}
irb> Product.first.relationship_entity_columns(:supplier)
=> {}
```

### Values

When a model is pushed to global registry, `global-registry-bindings` will attempt to determined the values for
each of the fields. This is done by calling the field name on the model. If the model responds, the value will be sent
with the entity. Model and implement or override values with a few different options. They can use
`alias_attribute :new_name, :old_name`, define a method `def field_name; "value"; end` or override
`entity_attributes_to_push` or `relationship_attributes_to_push` respectively. When the `*_attributes_to_push` methods
are used, you can modify values for other attributes as well as add additional fields and values. This is helpful
when adding fields and values which may not be tracked directly on this model. An instance of this is adding an
`authentication: { guid: 'UUID' }` field to a `person` entity_type to utilize Global Registry linked_identities.
See [Entity Matching](https://github.com/CruGlobal/global_registry_docs/wiki/Entity-Matching).

```ruby
class Person < ActiveRecord::Base
  alias_attribute :field1, :name

  global_registry_bindings fields: { name: string, description: :text, field1: :boolean, field2: :integer }
  
  def field2
    "#{name}:2"
  end
  
  def entity_attributes_to_push
    attrs = super # Calls super to get field values, then modify them.
    attrs[:description] = "Huge: #{attrs[:description]}"
    attrs[:authentication] = { guid: 'UUID' }
    attrs
  end
end
```
As an example, this would alias `field1` to `name` and use the method `field2` to determine the value for `field2`. It
subsequently changes the value of `:description` and adds an `:authentication` field using the
`entity_attributes_to_push` override.

## Conditional Push

Entities and relationships can be conditionally pushed to Global Registry using the `:if` and `:unless` options. These
options take either a Proc or a Symbol and should return true/false depending on if the Model should be pushed.

Using a proc:
```ruby
class Product < ActiveRecord::Base
  attr_accessor :should_push
  global_registry_bindings if: proc { |model| model.should_push }
end
```
Using a Symbol:
```ruby
class Product < ActiveRecord::Base
  global_registry_bindings unless: :should_push

  def should_push(_model)
    return ::GlobalConfig.gr_enabled?
  end
end
```

## Example Models

Example models can be found in the [specs](https://github.com/CruGlobal/global-registry-bindings/tree/master/spec/internal/app/models).

## Testing

Global Registry Bindings includes a testing helper to better help test your project when `gelobal-registry-bindings`
are included. Since Global Registry Bindings uses sidekiq, it's possible to have these workers executed in your
projects tests (ex: running sidekiq/testing in [inline!](https://github.com/mperham/sidekiq/wiki/Testing) mode). You
can use the following test modes:

```ruby
require 'global_registry_bindings/testing'
GlobalRegistry::Bindings::Testing.disable_test_helper! # disables the test helper, adding workers to a queue. (default).
GlobalRegistry::Bindings::Testing.skip_workers!
```

Each of the above methods also accepts a block.
```ruby
require 'global_registry_bindings/testing'
GlobalRegistry::Bindings::Testing.disable_test_helper!

# Some tests

around(:example) do |example|
  GlobalRegistry::Bindings::Testing.skip_workers!(&example)
end

# OR

GlobalRegistry::Bindings::Testing.skip_workers! do
  # Some other tests
end
```
