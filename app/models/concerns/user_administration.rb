module UserAdministration
  extend ActiveSupport::Concern

  included do
    attr_accessor :newly_accepted
    attr_accessor :send_invitation

    scope :accepted, -> {
      where("accepted_at IS NOT NULL")
    }

    scope :unaccepted, -> {
      where("accepted_at IS NULL")
    }

    scope :invited, -> {
      where("invited_at IS NOT NULL")
    }

    scope :uninvited, -> {
      where("invited_at IS NULL")
    }
    
    scope :invitable, -> {
      where("user_uid IS NOT NULL")
    }

    scope :uninvitable, -> {
      where("user_uid IS NULL")
    }
  end

  def status
    invited? ? accepted? ? "accepted" : "invited" : "uninvited"
  end

  def invited?
    invited_at?
  end

  def uninvited?
    !invited?
  end
  
  def invitable?
    user?
  end

  def accepted?
    accepted_at?
  end

  def unaccepted?
    !accepted?
  end
  
  # Note that this generally replaces the user-confirmation message that would be sent out by
  # the data room. Defer_confirmation should have been set on the newly-created user to prevent
  # the standard data room invitation also being sent out, and the acceptance route should always
  # take in a password-setting confirmation step.
  #
  def invite!
    if invitable?
      if Settings.mailer && defined? Settings.mailer.constantize
        mailer = Settings.mailer.constantize
        invitation = mailer.send("invitation_to_#{self.class.to_s.downcase}".to_sym, self)
        if invitation.deliver
          self.update_column :invited_at, Time.zone.now
        end
      end
    end
  end
  
  def remind!
    if invited?
      if Settings.mailer && defined? Settings.mailer.constantize
        mailer = Settings.mailer.constantize
        if mailer.respond_to? "reminder_to_#{self.class.to_s.downcase}".to_sym
          reminder = mailer.send("reminder_to_#{self.class.to_s.downcase}".to_sym, self)
          if reminder.deliver
            self.update_column :reminded_at, Time.zone.now
          end
        end
      end
    end
  end

  def accept!
    unless accepted?
      self.update_column :accepted_at, Time.zone.now
      self.newly_accepted = true
    end
  end

  def newly_accepted?
    !!newly_accepted
  end
  
  def inviting?
    !accepted? && send_invitation && send_invitation.to_s != "0"
  end
  
  private
  
  def invite_if_inviting
    self.invite! if inviting?
  end
  
end