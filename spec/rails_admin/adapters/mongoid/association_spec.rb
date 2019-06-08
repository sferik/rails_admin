require 'spec_helper'

describe 'RailsAdmin::Adapters::Mongoid::Association', mongoid: true do
  before :all do
    RailsAdmin::AbstractModel.reset_polymorphic_parents

    class MongoBlog
      include Mongoid::Document
      has_many :mongo_posts
      has_many :mongo_comments, as: :commentable
      belongs_to :librarian, polymorphic: true
      field :mongo_blog_id
    end

    class MongoPost
      include Mongoid::Document
      belongs_to :mongo_blog
      has_and_belongs_to_many :mongo_categories
      has_many :mongo_comments, as: :commentable
      embeds_one :mongo_note
      accepts_nested_attributes_for :mongo_note
    end

    class MongoCategory
      include Mongoid::Document
      has_and_belongs_to_many :mongo_posts
      belongs_to :librarian, polymorphic: true
    end

    class MongoUser
      include Mongoid::Document
      has_one :mongo_profile
      has_many :mongo_categories, as: :librarian

      embeds_many :mongo_notes
      accepts_nested_attributes_for :mongo_notes
      field :name, type: String
      field :message, type: String
      field :short_text, type: String

      validates :short_text, length: {maximum: 255}
    end

    class MongoProfile
      include Mongoid::Document
      belongs_to :mongo_user
      has_many :mongo_blogs, as: :librarian
    end

    class MongoComment
      include Mongoid::Document
      belongs_to :commentable, polymorphic: true
    end

    class MongoNote
      include Mongoid::Document
      embedded_in :mongo_post
      embedded_in :mongo_user
    end

    class MongoArticle
      include Mongoid::Document
      has_and_belongs_to_many :mongo_users, inverse_of: nil, primary_key: 'name', foreign_key: "users"
    end

    @blog     = RailsAdmin::AbstractModel.new MongoBlog
    @post     = RailsAdmin::AbstractModel.new MongoPost
    @category = RailsAdmin::AbstractModel.new MongoCategory
    @user     = RailsAdmin::AbstractModel.new MongoUser
    @profile  = RailsAdmin::AbstractModel.new MongoProfile
    @comment  = RailsAdmin::AbstractModel.new MongoComment
    @article  = RailsAdmin::AbstractModel.new MongoArticle
  end

  after :all do
    RailsAdmin::AbstractModel.reset_polymorphic_parents
  end

  it 'lists associations' do
    expect(@post.associations.collect { |a| a.name.to_sym }).to match_array [:mongo_blog, :mongo_categories, :mongo_comments, :mongo_note]
  end

  it 'reads correct and know types in [:belongs_to, :has_and_belongs_to_many, :has_many, :has_one]' do
    expect((@post.associations + @blog.associations + @user.associations).collect { |a| a.type.to_s }.uniq).to match_array %w(belongs_to has_and_belongs_to_many has_many has_one)
  end

  describe 'belongs_to association' do
    subject { @post.associations.detect { |a| a.name == :mongo_blog } }

    it 'returns correct values' do
      expect(subject.pretty_name).to eq 'Mongo blog'
      expect(subject.type).to eq :belongs_to
      expect(subject.klass).to eq MongoBlog
      expect(subject.primary_key).to eq :_id
      expect(subject.foreign_key).to eq :mongo_blog_id
      expect(subject.foreign_key_nullable?).to be_truthy
      expect(subject.foreign_type).to be_nil
      expect(subject.foreign_inverse_of).to be_nil
      expect(subject.as).to be_nil
      expect(subject.polymorphic?).to be_falsey
      expect(subject.inverse_of).to be_nil
      expect(subject.read_only?).to be_falsey
      expect(subject.nested_options).to be_nil
    end

    it 'distinguishes foreign_key column' do
      expect(@post.properties.detect { |f| f.name == :mongo_blog_id }.type).to eq(:bson_object_id)
      expect(@blog.properties.detect { |f| f.name == :mongo_blog_id }.type).to eq(:string)
    end
  end

  describe 'has_many association' do
    subject { @blog.associations.detect { |a| a.name == :mongo_posts } }

    it 'returns correct values' do
      expect(subject.pretty_name).to eq 'Mongo posts'
      expect(subject.type).to eq :has_many
      expect(subject.klass).to eq MongoPost
      expect(subject.primary_key).to eq :_id
      expect(subject.foreign_key).to eq :mongo_blog_id
      expect(subject.foreign_key_nullable?).to be_truthy
      expect(subject.foreign_type).to be_nil
      expect(subject.foreign_inverse_of).to be_nil
      expect(subject.as).to be_nil
      expect(subject.polymorphic?).to be_falsey
      expect(subject.inverse_of).to be_nil
      expect(subject.read_only?).to be_falsey
      expect(subject.nested_options).to be_nil
    end
  end

  describe 'has_and_belongs_to_many association' do
    subject { @post.associations.detect { |a| a.name == :mongo_categories } }

    it 'returns correct values' do
      expect(subject.pretty_name).to eq 'Mongo categories'
      expect(subject.type).to eq :has_and_belongs_to_many
      expect(subject.klass).to eq MongoCategory
      expect(subject.primary_key).to eq :_id
      expect(subject.foreign_key).to eq :mongo_category_ids
      expect(subject.foreign_key_nullable?).to be_truthy
      expect(subject.foreign_type).to be_nil
      expect(subject.foreign_inverse_of).to be_nil
      expect(subject.as).to be_nil
      expect(subject.polymorphic?).to be_falsey
      expect(subject.inverse_of).to be_nil
      expect(subject.read_only?).to be_falsey
      expect(subject.nested_options).to be_nil
      expect(subject.ref_ids_method).to eq :mongo_category_ids
    end
  end

  describe 'has_and_belongs_to_many association with custom primary_key and foreign_key' do
    subject { @article.associations.detect { |a| a.name == :mongo_users } }

    it 'returns correct values' do
      expect(subject.pretty_name).to eq 'Mongo users'
      expect(subject.type).to eq :has_and_belongs_to_many
      expect(subject.klass).to eq MongoUser
      expect(subject.primary_key).to eq :name
      expect(subject.foreign_key).to eq :users
      expect(subject.foreign_key_nullable?).to be_truthy
      expect(subject.foreign_type).to be_nil
      expect(subject.foreign_inverse_of).to be_nil
      expect(subject.as).to be_nil
      expect(subject.polymorphic?).to be_falsey
      expect(subject.inverse_of).to be_nil
      expect(subject.read_only?).to be_falsey
      expect(subject.nested_options).to be_nil
      expect(subject.ref_ids_method).to eq :users
    end
  end

  describe 'polymorphic belongs_to association' do
    before { allow(RailsAdmin::Config).to receive(:models_pool).and_return(%w(MongoBlog MongoPost MongoCategory MongoUser MongoProfile MongoComment)) }
    subject { @comment.associations.detect { |a| a.name == :commentable } }

    it 'returns correct values' do
      expect(subject.pretty_name).to eq 'Commentable'
      expect(subject.type).to eq :belongs_to
      expect(subject.klass).to eq [MongoBlog, MongoPost]
      expect(subject.primary_key).to eq :_id
      expect(subject.foreign_key).to eq :commentable_id
      expect(subject.foreign_key_nullable?).to be_truthy
      expect(subject.foreign_type).to eq :commentable_type
      expect(subject.foreign_inverse_of).to be_nil
      expect(subject.as).to be_nil
      expect(subject.polymorphic?).to be_truthy
      expect(subject.inverse_of).to be_nil
      expect(subject.read_only?).to be_falsey
      expect(subject.nested_options).to be_nil
    end
  end

  describe 'polymorphic inverse has_many association' do
    before { allow(RailsAdmin::Config).to receive(:models_pool).and_return(%w(MongoBlog MongoPost MongoCategory MongoUser MongoProfile MongoComment)) }
    subject { @blog.associations.detect { |a| a.name == :mongo_comments } }

    it 'returns correct values' do
      expect(subject.pretty_name).to eq 'Mongo comments'
      expect(subject.type).to eq :has_many
      expect(subject.klass).to eq MongoComment
      expect(subject.primary_key).to eq :_id
      expect(subject.foreign_key).to eq :commentable_id
      expect(subject.foreign_key_nullable?).to be_truthy
      expect(subject.foreign_type).to be_nil
      expect(subject.foreign_inverse_of).to be_nil
      expect(subject.as).to eq :commentable
      expect(subject.polymorphic?).to be_falsey
      expect(subject.inverse_of).to be_nil
      expect(subject.read_only?).to be_falsey
      expect(subject.nested_options).to be_nil
    end

    it 'looks up correct inverse model' do
      expect(@category.associations.detect { |a| a.name == :librarian }.klass).to eq [MongoUser]
      expect(@blog.associations.detect { |a| a.name == :librarian }.klass).to eq [MongoProfile]
    end
  end

  describe 'embeds_one association' do
    subject { @post.associations.detect { |a| a.name == :mongo_note } }

    it 'returns correct values' do
      expect(subject.pretty_name).to eq 'Mongo note'
      expect(subject.type).to eq :has_one
      expect(subject.klass).to eq MongoNote
      expect(subject.primary_key).to eq :_id
      expect(subject.foreign_key).to be_nil
      expect(subject.foreign_key_nullable?).to be_falsey
      expect(subject.foreign_type).to be_nil
      expect(subject.foreign_inverse_of).to be_nil
      expect(subject.as).to be_nil
      expect(subject.polymorphic?).to be_falsey
      expect(subject.inverse_of).to be_nil
      expect(subject.read_only?).to be_falsey
      expect(subject.nested_options).to eq(allow_destroy: false, update_only: false)
    end
  end

  describe 'embeds_many association' do
    subject { @user.associations.detect { |a| a.name == :mongo_notes } }

    it 'returns correct values' do
      expect(subject.pretty_name).to eq 'Mongo notes'
      expect(subject.type).to eq :has_many
      expect(subject.klass).to eq MongoNote
      expect(subject.primary_key).to eq :_id
      expect(subject.foreign_key).to be_nil
      expect(subject.foreign_key_nullable?).to be_falsey
      expect(subject.foreign_type).to be_nil
      expect(subject.as).to be_nil
      expect(subject.polymorphic?).to be_falsey
      expect(subject.inverse_of).to be_nil
      expect(subject.read_only?).to be_falsey
      expect(subject.nested_options).to eq(allow_destroy: false, update_only: false)
    end

    it 'raises error when embeds_* is used without accepts_nested_attributes_for' do
      class MongoEmbedsOne
        include Mongoid::Document
        embeds_one :mongo_embedded
      end

      class MongoEmbedsMany
        include Mongoid::Document
        embeds_many :mongo_embeddeds
      end

      class MongoEmbedded
        include Mongoid::Document
        embedded_in :mongo_embeds_one
        embedded_in :mongo_embeds_many
      end

      class MongoRecursivelyEmbedsOne
        include Mongoid::Document
        recursively_embeds_one
      end

      class MongoRecursivelyEmbedsMany
        include Mongoid::Document
        recursively_embeds_many
      end

      expect { RailsAdmin::AbstractModel.new(MongoEmbedsOne).associations.first.nested_options }.to raise_error(RuntimeError, "Embbeded association without accepts_nested_attributes_for can't be handled by RailsAdmin,\nbecause embedded model doesn't have top-level access.\nPlease add `accepts_nested_attributes_for :mongo_embedded' line to `MongoEmbedsOne' model.\n")
      expect { RailsAdmin::AbstractModel.new(MongoEmbedsMany).associations.first.nested_options }.to raise_error(RuntimeError, "Embbeded association without accepts_nested_attributes_for can't be handled by RailsAdmin,\nbecause embedded model doesn't have top-level access.\nPlease add `accepts_nested_attributes_for :mongo_embeddeds' line to `MongoEmbedsMany' model.\n")
      expect { RailsAdmin::AbstractModel.new(MongoRecursivelyEmbedsOne).associations.first.nested_options }.not_to raise_error
      expect { RailsAdmin::AbstractModel.new(MongoRecursivelyEmbedsMany).associations.first.nested_options }.not_to raise_error
    end

    it 'works with inherited embeds_many model' do
      class MongoEmbedsParent
        include Mongoid::Document
        embeds_many :mongo_embeddeds
        accepts_nested_attributes_for :mongo_embeddeds
      end

      class MongoEmbedded
        include Mongoid::Document
        embedded_in :mongo_embeds_many
      end

      class MongoEmbedsChild < MongoEmbedsParent; end

      expect { RailsAdmin::AbstractModel.new(MongoEmbedsChild).associations }.not_to raise_error
    end
  end
end
