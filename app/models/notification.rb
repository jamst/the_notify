class Notification < ApplicationRecord
  belongs_to :receiver, polymorphic: true

  default_scope -> { order(id: :desc) }
  scope :unread, -> { where(read_at: nil) }
  scope :have_read, -> { where.not(read_at: nil) }

  after_create_commit :process_job, :update_unread_count

  def process_job
    if sending_at
      NotificationJob.set(wait_until: sending_at).perform_later id
    else
      NotificationJob.perform_later(self.id)
    end
  end

  def unread_count
    Rails.cache.read("#{receiver_type}_#{self.receiver_id}_unread") || 0
  end

  def update_unread
    if read_at.blank?
      update(read_at: Time.now)
      Rails.cache.decrement "#{receiver_type}_#{self.receiver_id}_unread"
    end
  end

  def update_unread_count
    Rails.cache.write "#{receiver_type}_#{self.receiver_id}_unread", Notification.where(receiver_id: self.receiver_id, read_at: nil).count, raw: true
  end

  def add_redis_message
    message_hash = Redis::HashKey.new("employee_#{self.employee_id}")
    message_hash["#{CGI.escape(self.link)}"] = "#{self.msg}"
  end

  def self.update_unread_count(receiver)
    Rails.cache.write "#{receiver.class.name}_#{receiver.id}_unread", Notification.where(receiver_id: receiver.id, read_at: nil).count, raw: true
  end

end

# notifiable_type:
# notifiable_id: