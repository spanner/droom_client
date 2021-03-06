# The purpose of this module is to make it easy to associate a droom user to a local object.
# It often happens that...
#
# Since the user is a remote resource, this association only partly resembles a normal activerecord association.
#
# Requirements: user_uid column.
#
module HasDroomUser
  extend ActiveSupport::Concern

  included do
    scope :by_user, -> user_or_uid {
      uid = user_or_uid.respond_to?(:uid) ? user_or_uid.uid : user_or_uid
      where(user_uid: uid)
    }
  end

  ## Get
  #
  # Users are associated by uid in the hope of database and device independence. All we do here is go and get the user.
  #
  def user
    begin
      if user_uid?
        @_user ||= User.find(user_uid)
      end
      if respond_to?(:email?) && email?
        @_user ||= User.where(email: email).first
      end
    rescue => e
      Rails.logger.warn "#{self.class} #{self.id} has a user_uid that corresponds to no known data room user. Perhaps someone has been deleted? Ignoring. Error: #{e}"
      nil
    end
    @_user
  end

  def find_or_create_user
    unless user
      if email
        @_user = User.create({
          given_name: given_name,
          family_name: family_name,
          chinese_name: chinese_name,
          email: email
        })
        self.user_uid = @_user.uid
      end
    end
    @_user
  end

  ## Set
  #
  # Users are assigned in two ways: by direct association to an existing user object, or by the inline creation of a new
  # user object during the creation of a local object.
  #
  # ### Assigning an existing user
  #
  # +user=+ will be called in two situations: during a compound save with an existing user object,
  # or immediately upon the creeation of a new user, on the object that it was created with.
  # We only complete the save if nothing else is going on: if this record is new or has other changes,
  # we assume that this is part of a larger save operation.
  #
  def user=(user)
    also_save = self.persisted? && !self.changed?
    self.user_uid = user.uid
    @_user = user
    self.save if also_save
  end

  # Nil or value is meaningful. Empty string means that no value was set.
  def user_uid=(uid="")
    if uid != ""
      write_attribute(:user_uid, uid)
    end
  end

  # ### Nested creation of a new user
  #
  # +user_attributes=+ is only usually called during the nested creation of a new user object but it
  # is also possible for people to update some of their account settings through a remote service.
  #
  def user_attributes=(attributes)
    if attributes.any?
      if user = self.user
        user.update_attributes(attributes.with_indifferent_access)
        user.save
      else
        attributes.reverse_merge!(defer_confirmation: confirmation_usually_deferred?)
        Rails.logger.warn "!!! NEW USER attributes=#{attributes.inspect}"
        user = User.new_with_defaults(attributes)
        user.save
        Rails.logger.warn "!!! CREATED USER with uid #{user.uid}"
        self.user = user
      end
    end
  end
  
  def confirmation_usually_deferred?
    true
  end

  def user?
    user_uid? && user.present?
  end
  
  def confirmed?
    !!user.confirmed if user?
  end
  
  def name
    user.name if user?
  end

  def formal_name
    user.formal_name if user?
  end

  def informal_name
    user.informal_name if user?
  end

  def colloquial_name
    user.colloquial_name if user?
  end

  def title_if_it_matters
    user.title_if_it_matters if user?
  end

  def icon
    user.icon if user?
  end

  def email
    read_attribute(:email) || user_email
  end
  
  def user_email
    user.email if user?
  end

end