class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable, :lockable and :timeoutable
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :trackable, :validatable

  serialize :roles, Array

  # Add Paperclip support for avatars
  has_attached_file :avatar, styles: {medium: '300x300>', thumb: '100x100>'}

  attr_accessor :delete_avatar
  before_validation { self.avatar = nil if delete_avatar == '1' }

  def attr_accessible_role
    :custom_role
  end

  def roles_enum
    %i[admin user]
  end
end
