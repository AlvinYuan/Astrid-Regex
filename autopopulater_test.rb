require 'test/unit'
require 'autopopulate.rb'
require 'time'

#priority
#title
#date -> day of the week of next 
#time 
#repeat (interval)
#repeat (frequency)
#list(s)

#list_name #(list name with spaces)

class TaskTest < Test::Unit::TestCase  

  #Basic tasks
  def test_basic
    tasks = ["Jog", "pick up groceries"]
    tasks.each {|task|
      title = task;
      expected = {:title => title}
      assert_equal(expected, Autopopulate.autopopulate(title))
    }
  end

  #Tests different accepted priority strings
  def test_priorities_basic
    expected = {:title => "Jog"}
    task = "Jog"
    priorities = {"0" => 0, "!!!" => 3, "!2" => 2, "!5" => 3}
    priorities.each{|str,p|
      title = [task,str].join(" ")
      expected[:priority] = p
      assert_equal(expected, Autopopulate.autopopulate(title))
    }
  end
  
  #Tests priority and formatting (punctuation, placement) interaction
  def test_priorities_with_punctuation
    title = "Jog !."
    expected = {:title => "Jog", :priority => 1}
    assert_equal(expected, Autopopulate.autopopulate(title))
    
    title = "!1 Jog."
    expected = {:title => "Jog.", :priority => 1}    
    assert_equal(expected, Autopopulate.autopopulate(title))
    
    title = "!!!, Jog"
    expected = {:title => "Jog", :priority => 3}
    assert_equal(expected, Autopopulate.autopopulate(title))    
    
    title = "Jog.!!!"
    expected = {:title => "Jog", :priority => 3}
    assert_equal(expected, Autopopulate.autopopulate(title))   

    title = "Jog (!!!) slowly"
    expected = {:title => "Jog slowly", :priority => 3}
    assert_equal(expected, Autopopulate.autopopulate(title))   
  end
     
  #Tests different accepted time formats with punctuation
  def test_times
    task = "Jog"
    times = ["at 8", "8AM, 1 mile", ":8 o'clock", "8:00", "8 a.m.", "in the morning."]
    time = Chronic.parse("8AM")
    times.each{|t|
      title = [task,t].join(" ")
      expected = {:title => title, :time => time}
      assert_equal(expected, Autopopulate.autopopulate(title))
    }
  end

  #Tests single word lists and formatting (punctuation, placement) interaction
  def test_lists_single_word
    #Single word list
    title = "Jog #health"
    expected = {:title => "Jog", :list => Set.new(["health"])}
    assert_equal(expected, Autopopulate.autopopulate(title))
    
    #Single word list + punctuation
    title = "Jog #a."
    expected = {:title => "Jog", :list => Set.new(["a"])}
    assert_equal(expected, Autopopulate.autopopulate(title))
    
    #Single word list in front
    title = "#joy, Jog"
    expected = {:title => "Jog", :list => Set.new(["joy"])}
    assert_equal(expected, Autopopulate.autopopulate(title))
  end
  
  #Tests multi-word lists
  def test_lists_multi_word  
    title = "Jog #(new years)"
    expected = {:title => "Jog", :list => Set.new(["new years"])}
    assert_equal(expected, Autopopulate.autopopulate(title))

    title = "#(new years), Jog"
    expected = {:title => "Jog", :list => Set.new(["new years"])}
    assert_equal(expected, Autopopulate.autopopulate(title))
  end
  
  #Tests multiple lists in title
  def test_lists_multiple
    title = "#exercise. Jog #(new years) briskly #health"
    expected = {:title => "Jog briskly", :list => Set.new(["exercise", "new years", "health"])}
    assert_equal(expected, Autopopulate.autopopulate(title))
  end

  #Tests repeats
  def test_repeats
    title = "Jog every day"
    expected = {:title => title, :repeat => {:freq => "day", :interval => 1}}
    assert_equal(expected, Autopopulate.autopopulate(title))
    
    title = "monthly jog"
    expected = {:title => title, :repeat => {:freq => "month", :interval => 1}}
    assert_equal(expected, Autopopulate.autopopulate(title))
    
    title = "jog every other week"
    expected = {:title => title, :repeat => {:freq => "week", :interval => 2}}
    assert_equal(expected, Autopopulate.autopopulate(title))

    title = "jog every three days"
    expected = {:title => title, :repeat => {:freq => "day", :interval => 3}}
    assert_equal(expected, Autopopulate.autopopulate(title))
    
    #Ignores :day
    title = "jog every two Tuesdays"
    expected = {:title => title, :repeat => {:freq => "week", :interval => 2}}
    result = Autopopulate.autopopulate(title)
    result.delete(:day)
    assert_equal(expected, result)
  end

  #Tests for words that would be recognized as a date (Monday-Friday, today, tomorrow)
  def test_day
    title = "Jog on wednesday"
    expected = {:title => title, :day => Date.parse(Chronic.parse("Wednesday").strftime("%Y-%m-%d"))} #%F not working for Alvin
    assert_equal(expected, Autopopulate.autopopulate(title))

    title = "tomorrow, Jog"
    expected = {:title => title, :day => Date.parse(Chronic.parse("tomorrow").strftime("%Y-%m-%d"))} #%F not working for Alvin
    assert_equal(expected, Autopopulate.autopopulate(title))

    title = "Jog (today) briskly"
    expected = {:title => "Jog briskly", :day => Date.parse(Chronic.parse("today").strftime("%Y-%m-%d"))} #%F not working for Alvin
    assert_equal(expected, Autopopulate.autopopulate(title))
  end

  #Tests for date recognition
  def test_date
    title = "Jog on 12/30"
    expected = {:title => title, :day => Date.parse("12/30/2012")}#Change so year is flexible
    assert_equal(expected, Autopopulate.autopopulate(title))
    
    title = "Jog on February 22nd"
    expected = {:title => title, :day => Date.parse("2/22/2012")}#Change so year is flexible
    assert_equal(expected, Autopopulate.autopopulate(title))   
    
    #Test for false match of March 3
    title = "Go to the market and buy 3 apples"
    expected = {:title => title}
    assert_equal(expected, Autopopulate.autopopulate(title))
  end
  
  #Tests various combinations of various fields
  def test_combinations
    title = "Jog at 8AM #health #resolutions"
    expected = {:title => "Jog at 8AM", 
    			:list => Set.new(["resolutions", "health"]), 
    			:time => Chronic.parse("8AM")}
    assert_equal(expected, Autopopulate.autopopulate(title))

    title = "Every day 8AM jog #health #resolutions starting tomorrow"
    expected = {:title => "Every day 8AM jog starting tomorrow", 
                :list => Set.new(["resolutions", "health"]), 
                :time => Chronic.parse("8AM"),
                :day => Date.parse(Chronic.parse("tomorrow").strftime("%Y-%m-%d")),
                :repeat => {:freq => "day", :interval => 1}
                }
    assert_equal(expected, Autopopulate.autopopulate(title))

    title = "!!! Every week 8:00 jog #(new years) #resolutions"
    expected = {:title => "Every week 8:00 jog", 
                :list => Set.new(["resolutions", "new years"]), 
                :time => Chronic.parse("8:00"),
                :priority => 3,
                :repeat => {:freq => "week", :interval => 1}
                }
    assert_equal(expected, Autopopulate.autopopulate(title))

    title = "!!! Every other day #health 8AM jog #resolutions"
    expected = {:title => "Every other day 8AM jog", 
                :list => Set.new(["resolutions", "health"]), 
                :time => Chronic.parse("8AM"),
                :priority => 3,
                :repeat => {:freq => "day", :interval => 2}
                }
    assert_equal(expected, Autopopulate.autopopulate(title))  
    end  
  
  #Tests usage of next
  def test_next
    title = "Jog next week"
    expected = {:title => "Jog next week", :day => Date.parse(Chronic.parse("next week").strftime("%Y-%m-%d"))} #%F not working for Alvin
    assert_equal(expected, Autopopulate.autopopulate(title))
    
    title = "Jog next month"
    expected = {:title => "Jog next month", :day => Date.parse(Chronic.parse("next month").strftime("%Y-%m-%d"))} #%F not working for Alvin
    assert_equal(expected, Autopopulate.autopopulate(title))
    
    title = "Jog next year"
    expected = {:title => "Jog next year", :day => Date.parse(Chronic.parse("next year").strftime("%Y-%m-%d"))} #%F not working for Alvin
    assert_equal(expected, Autopopulate.autopopulate(title))
    end
    
end