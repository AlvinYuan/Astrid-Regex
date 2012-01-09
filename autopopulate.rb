require 'time'
require 'rubygems'
require 'chronic'
require 'set'
require 'date'

class Autopopulate  
  def self.autopopulate(task)
    results = {:title => task}
    unless results[:title].nil?    
      autopopulateDate(results)
      autopopulateTime(results)
      autopopulateRepeat(results)
      autopopulatePriority(results)
      autopopulateLists(results)
    end      
    return results 
  end

=begin
    results[:day] should hold a Date object or be unspecified.
    The Date object should have the correct date based on results[:title].
    If no date is specified in the title, then the field should be unspecified. 
=end  
  def self.autopopulateDate(results)
    #Add support for "second Wednesday of March?"
    { 
      /today/i => "Today",
      /tomorrow/i => "Tomorrow",
      /monday/i => "Monday",
      /tuesday/i => "Tuesday",
      /wednesday/i => "Wednesday",
      /thursday/i => "Thursday",
      /friday/i => "Friday",
      /saturday/i => "Saturday",
      /sunday/i => "Sunday",
    }.each { |regex, due| 
      if results[:title] =~ regex and results[:day].nil?
        #if results[:day] not nil, 2 dates specified in task
        day = Chronic.parse(due).strftime("%Y-%m-%d") #%F not working for Alvin?
        results[:day] = Date.parse(day)

        # If date is in parentheses, remove it from the title
        # This was mainly added for email API but the stripping will also happen if the task is added from the UI.
        results[:title] = results[:title].gsub(Regexp.new("\s*\\(" + regex.to_s + "\\)"), "")
      end
    }

    #representing dates
    #simplify using variable substitution?
    #compress into fewer regexes?
    ds = "3[0-1]|[0-2]?[0-9]" #day string for date regexes
    [
      /(\b1?[1-9](\/|-)(#{ds})(\b|\/|-))/, #Check for [1-12]/[1-30] or [1-12]-[1-30]
      /(jan.*(#{ds}))/i,
      /(feb.*(3[0-1]|[0-2]?[0-9]))/i,
      /(mar.*(3[0-1]|[0-2]?[0-9]))/i,
      /(apr.*(3[0-1]|[0-2]?[0-9]))/i,
      /(may.*(3[0-1]|[0-2]?[0-9]))/i,
      /(jun.*(3[0-1]|[0-2]?[0-9]))/i,
      /(jul.*(3[0-1]|[0-2]?[0-9]))/i,
      /(aug.*(3[0-1]|[0-2]?[0-9]))/i,
      /(sep.*(3[0-1]|[0-2]?[0-9]))/i,
      /(oct.*(3[0-1]|[0-2]?[0-9]))/i,
      /(nov.*(3[0-1]|[0-2]?[0-9]))/i,
      /(dec.*(3[0-1]|[0-2]?[0-9]))/i
    ].each { |regex|
      match = results[:title].match(regex)
      if match and results[:day].nil?
        begin
        date = Date.parse(match[1]) #Convert to date object
        if date - Date.today < -30 #If day is more than a month in the past, add a year
          results[:day] = Date.new(date.year + 1, date.mon, date.day)
        else
          results[:day] = date
        end
        rescue #catch invalid dates
        end
      end 
    }
  end

  
=begin
    results[:time] should hold a Time object or be unspecified.
    The Time object should have the correct time based on results[:title].
    If no time is specified in the title, then the field should be unspecified. 
    Only the hour and minutes of the Time object should be used.
=end
  def self.autopopulateTime(results)
    #Once a match is found, no more regexes are searched for. 
    #Therefore highest priority must be at top.
    [
      #[time] am/pm
      /\b(\d.* ?[ap]\.?m\.?)\b/i,       
      #[army time]
      /\b([0-2]?[0-9]:[0-5][0-9])\b/i,
      #at [int]
      /\bat ([01]?\d)($|\D($|\D))/i,
      #[int] o'clock
      /\b([01]?\d ?o'? ?clock)\b/i
    ].each { |regex| 
      match = results[:title].match(regex)
      if match
        results[:time] = Chronic.parse(match[1])
        break
      end
    }
    
    #common times of day  
    { 
      /morning/i => "8:00",
      /afternoon/i => "15:00",
      /evening/i => "19:00",
      /night/i => "19:00",
      /midnight/i => "0:00",
      /noon/i => "12:00"
    }.each { |regex, due| 
      results[:time] = Chronic.parse(due) if results[:title] =~ regex
    }
  end

=begin
    results[:repeat] should hold a hash or be unspecified.
    The hash should hold a value for :freq and :interval based on results[:title]
    If no repeat is specified in the title, then the field should be unspecified. 
    ADD IN SUPPORT FOR every other day (interval 2), every monday (freq week)
=end
  def self.autopopulateRepeat(results)
    #.{0,6} will hopefully contain interval information. Ex: other, 2, three, etc.
    { 
      #interval determined by find_interval(results) looking at .{0,6} (ex: every three days)
      /\bevery.{0,6} days?\b/i => {:freq => "day"},
      /\bevery.{0,6} weeks?\b/i => {:freq => "week"},
      /\bevery.{0,6} (mon|tues|wednes|thurs|fri|satur|sun)days?\b/i => {:freq => "week"},
      /\bevery.{0,6} months?\b/i => {:freq => "month"},
      /\bevery.{0,6} years?\b/i => {:freq => "year"},
      
      #pre-determined intervals
      /\bdaily\b/i => {:freq => "day", :interval => 1},
      /\bweekly\b/i => {:freq => "week", :interval => 1},
      /\bmonthly\b/i => {:freq => "month", :interval => 1},
      /\byearly\b/i => {:freq => "year", :interval => 1}      
    }.each { |regex, repeat| 
      match = results[:title].match(regex) 
      if match
        repeat[:interval] = find_interval(results) if repeat[:interval].nil?
        results[:repeat] = repeat
        break
      end
    }
  end
  
  #Checks up to an interval of 9, for 9 months (pregnancy?)
  #Checks up to an interval of 12, for 12 months
  def self.find_interval(results)
    words_to_nums = {"one" => 1, "1" => 1, 
                     "two" => 2, "2" => 2, "other" => 2, 
                     "three" => 3, "3" => 3, 
                     "four" => 4, "4" => 4, #"first" => 4, "second" => 4, "third" => 4, "fourth" => 4,
                     "five" => 5, "5" => 5, 
                     "six" => 6, "6" => 6,
                     "seven" => 7, "7" => 7,
                     "eight" => 8, "8" => 8,
                     "nine" => 9, "9" => 9,
                     "ten" => 10, "10" => 10,
                     "eleven" => 11, "11" => 11,
                     "twelve" => 12, "12" => 12
                     }
    match = results[:title].match(/\bevery (\w*)\b/i)
    interval = 1
    unless match.nil? || match[1].nil?
      interval_str = match[1]
      interval = words_to_nums[interval_str] unless words_to_nums[interval_str].nil?
    end
    return interval
  end
  
=begin
    results[:priority] should hold an int between 0 and 3 or be unspecified.
    The int should be set based on a priority string in results[:title]
    If no priority is specified in the title, then the field should be unspecified. 
    The specified priority string will then be removed from results[:title]
=end
  def self.autopopulatePriority(results)
    match = results[:title].match(/(.*)(^|[^\w!])(!+|0|!\d)($|[^\w!])(.*)/)
    if match
      #match[2] and match[4] is punctuation that if kept in the title, 
      #would make it look strange in some cases?
      results[:title] = [match[1], match[-1]].join(" ").split.join(" ")#nice spacing
      #makes it so match[1] and match[5] do not need to have their own spaces
      results[:priority] = str_to_priority(match[3])
    end
  end

  def self.str_to_priority(priority_str)
    priority = 3
    priority = 0 if priority_str == '0' || priority_str == '!0'
    priority = 1 if priority_str == '!' || priority_str == '!1'
    priority = 2 if priority_str == '!!' || priority_str == '!2'
    return priority
  end
=begin
    results[:lists] should hold a Set of list strings or be unspecified.
    The Set should have all lists specified based on results[:title].
    If no lists are specified in the title, then the field should be unspecified. 
    The specified lists will then be removed from results[:title]
=end
  def self.autopopulateLists(results)
    lists = Set.new()
    list_regex = /(.*)(^|\W)#(\(.*\)|\w+)($|\W)(.*)/i
    match = results[:title].match(list_regex)
    while match
      list = match[3]
      list = list[1..-2] if list[0,1] == "("
      lists.add(list);
      results[:title] = [match[1], match[-1]].join(" ").split.join(" ")
      match = results[:title].match(list_regex)
    end
    results[:list] = lists unless lists.empty?
  end
end