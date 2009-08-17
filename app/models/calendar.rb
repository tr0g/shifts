class Calendar < ActiveRecord::Base
  has_many :shifts
  has_many :time_slots
  has_many :repeating_events
  belongs_to :department

  validates_presence_of :name
  validates_presence_of :start_date
  validates_presence_of :end_date, :if => Proc.new{|calendar| !calendar.default?}

  validates_uniqueness_of :name, :scope => :department_id

  named_scope :active, lambda {{ :conditions => {:active => true}}}

  def self.destroy_self_and_future(calendar)
    default_id = calendar.department.calendars.default.id
    TimeSlot.delete_all("#{:calendar_id.to_sql_column} = #{calendar.id.to_sql} AND #{:end.to_sql_column} > #{Time.now.utc.to_sql}")
    TimeSlot.update_all("#{:calendar_id.to_sql_column} = #{default_id.to_sql}", "#{:calendar_id.to_sql_column} = #{calendar.id.to_sql}")
    Shift.delete_all("#{:calendar_id.to_sql_column} = #{calendar.id.to_sql} AND #{:end.to_sql_column} > #{Time.now.utc.to_sql}")
    Shift.update_all("#{:calendar_id.to_sql_column} = #{default_id.to_sql}", "#{:calendar_id.to_sql_column} = #{calendar.id.to_sql}")
    calendar.destroy
  end

  def self.copy(old_calendar, new_calendar, wipe)
    errors = ""
    old_calendar.repeating_events.each do |r|
      new_repeating_event = r.clone
      new_repeating_event.start_date = new_calendar.start_date
      new_repeating_event.end_date = new_calendar.end_date
      new_repeating_event.calendar = new_calendar
      new_repeating_event.save!
      error = new_repeating_event.make_future(wipe)
      errors += ","+error if error
      end
      errors
  end

  def deactivate
    self.active = false
    TimeSlot.update_all("#{:active.to_sql_column} = #{false.to_sql}", "#{:calendar_id.to_sql_column} = #{self.id.to_sql}")
    Shift.update_all("#{:active.to_sql_column} = #{false.to_sql}", "#{:calendar_id.to_sql_column} = #{self.id.to_sql}")
    self.save
  end

  def activate(wipe)
    self.active = true
    conflicts = Shift.check_for_conflicts(Shift.find(:all, :conditions => ["calendar_id = #{self.id.to_sql} AND start > #{Time.now.utc.to_sql}"]), wipe) + TimeSlot.check_for_conflicts(TimeSlot.find(:all, :conditions=>["calendar_id = #{self.id.to_sql} AND start > #{Time.now.utc.to_sql}"]), wipe)
    if conflicts.empty?
      TimeSlot.update_all("#{:active.to_sql_column} = #{true.to_sql}", "#{:calendar_id.to_sql_column} = #{self.id.to_sql} AND #{:start.to_sql_column} > #{Time.now.utc.to_sql}")
      Shift.update_all("#{:active.to_sql_column} = #{true.to_sql}", "#{:calendar_id.to_sql_column} = #{self.id.to_sql} AND #{:start.to_sql_column} > #{Time.now.utc.to_sql}")
      self.save
      return false
    else
      return conflicts
    end
  end

end
