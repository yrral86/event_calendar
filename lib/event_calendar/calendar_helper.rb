module EventCalendar
  module CalendarHelper

    # Returns an HTML calendar which can show multiple, overlapping events across calendar days and rows.
    # Customize using CSS, the below options, and by passing in a code block.
    #
    # The following are optional, available for customizing the default behaviour:
    # :month => Time.now.month # The month to show the calendar for. Defaults to current month.
    # :year => Time.now.year # The year to show the calendar for. Defaults to current year.
    # :dates => (start_date .. end_date) # Show specific range of days. Defaults to :year, :month.
    # :abbrev => true # Abbreviate day names. Reads from the abbr_day_names key in the localization file.
    # :first_day_of_week => 0 # Renders calendar starting on Sunday. Use 1 for Monday, and so on.
    # :show_today => true # Highlights today on the calendar using CSS class.
    # :show_header => true # Show the calendar's header. (month name, next, & previous links)
    # :month_name_text => nil # Displayed center in header row.
    #     Defaults to current month name from Date::MONTHNAMES hash.
    # :previous_month_text => nil # Displayed left of the month name if set
    # :next_month_text => nil # Displayed right of the month name if set
    # :event_strips => [] # An array of arrays, encapsulating the event rows on the calendar
    #
    # :width => nil # Width of the calendar, if none is set then it will stretch the container's width
    # :height => 500 # Approx minimum total height of the calendar (excluding the header).
    #     Height could get added if a day has too many event's to fit.
    # :day_names_height => 18 # Height of the day names table (included in the above 'height' option)
    # :day_nums_height => 18 # Height of the day numbers tables (included in the 'height' option)
    # :event_height => 18 # Height of an individual event row
    # :event_margin => 1 # Spacing of the event rows
    # :event_padding_top => 1 # Padding on the top of the event rows (increase to move text down)
    #
    # :use_all_day => false # If set to true, will check for an 'all_day' boolean field when displaying an event.
    #     If it is an all day event, or the event is multiple days, then it will display as usual.
    #     Otherwise it will display without a background color bar.
    # :use_javascript => true # Outputs HTML with inline javascript so events spanning multiple days will be highlighted.
    #     If this option is false, cleaner HTML will be output, but events spanning multiple days will
    #     not be highlighted correctly on hover, so it is only really useful if you know your calendar
    #     will only have single-day events. Defaults to true.
    # :link_to_day_action => false # If controller action is passed,
    #     the day number will be a link. Override the day_link method for greater customization.
    #
    # For more customization, you can pass a code block to this method
    # The varibles you have to work with in this block are passed in an agruments hash:
    # :event => The event to be displayed.
    # :day => The day the event is displayed on. Usually the first day of the event, or the first day of the week,
    #   if the event spans a calendar row.
    # :options => All the calendar options in use. (User defined and defaults merged.)
    #
    # For example usage, see README.
    #
    # override this in your own helper for greater control
    #

    def calendar(options = {}, &block)
      block ||= Proc.new {|d| nil}

      options = defaults.merge options
      cal = Calendar.new options, block

    end


    def defaults
      {
        :year =>  (Time.zone || Time).now.year,
        :month => (Time.zone || Time).now.month,
        :abbrev => true,
        :first_day_of_week => 0,
        :show_today => true,
        :show_header => true,
        :month_name_text => (Time.zone || Time).now.strftime("%B %Y"),
        :previous_month_text => nil,
        :next_month_text => nil,
        :event_strips => [],

        # it would be nice to have these in the CSS file
        # but they are needed to perform height calculations
        :width => nil,
        :height => 500,
        :day_names_height => 18,
        :day_nums_height => 18,
        :event_height => 18,
        :event_margin => 1,
        :event_padding_top => 2,

        :use_all_day => false,
        :use_javascript => true,
        :link_to_day_action => false
      }
    end

    class Calendar
      attr_reader :row_num, :first_day_of_week, :last_day_of_week, :last_day_of_cal, :top, :first, :last, :options

      def initialize options, block=nil
        @block = block

        # default month name for the given number
        if options[:show_header]
          options[:month_name_text] ||= I18n.translate(:'date.month_names')[options[:month]]
        end

        # the first and last days of this calendar month
        if options[:dates].is_a?(Range)
          @first = options[:dates].begin
          @last = options[:dates].end
        else
          @first = Date.civil(options[:year], options[:month], 1)
          @last = Date.civil(options[:year], options[:month], -1)
        end

        @options = options
        @html = ""

        outer_calendar_container do
          table_header_and_links

          body_container_for_day_names_and_rows do
            add_day_names
            calendar_rows_container do
              add_weeks
            end
          end
        end
      end

      def to_s
        @html
      end

      def << value
        @html << value 
      end

      private
      def outer_calendar_container
        self << %(<div class="ec-calendar")
        self << %(style="width: #{options[:width]}px;") if options[:width]
        self << %(>)
        yield

        self << %(</div>)
      end

      def table_header_and_links
        if options[:show_header]
          self << %(<table class="ec-calendar-header" cellpadding="0" cellspacing="0">)
          self << %(<thead><tr>)
          if options[:previous_month_text] or options[:next_month_text]
            self << %(<th colspan="2" class="ec-month-nav ec-previous-month">#{options[:previous_month_text]}</th>)
            colspan = 3
          else
            colspan = 7
          end

          self << %(<th colspan="#{colspan}" class="ec-month-name">#{options[:month_name_text]}</th>)

          if options[:next_month_text]
            self << %(<th colspan="2" class="ec-month-nav ec-next-month">#{options[:next_month_text]}</th>)
          end
          self << %(</tr></thead></table>)
        end
      end

      def body_container_for_day_names_and_rows
        self << %(<div class="ec-body" style="height: #{height}px;">)
        yield
        self << %(</div>)
      end

      def add_day_names
        self << %(<table class="ec-day-names" style="height: #{options[:day_names_height]}px;" cellpadding="0" cellspacing="0">)
        self << %(<tbody><tr>)
        day_names.each do |day_name|
          self << %(<th class="ec-day-name" title="#{day_name}">#{day_name}</th>)
        end
        self << %(</tr></tbody></table>)
      end

      def calendar_rows_container
        self << %(<div class="ec-rows" style="top: #{options[:day_names_height]}px; )
        self << %(height: #{height - options[:day_names_height]}px;">)
        yield

        self << %(</div>)
      end

      def add_weeks
        # initialize loop variables
        @first_day_of_week = beginning_of_week(first, options[:first_day_of_week])
        @last_day_of_week = end_of_week(first, options[:first_day_of_week])
        @last_day_of_cal = end_of_week(last, options[:first_day_of_week])
        @row_num = 0
        @top = 0

        # go through a week at a time, until we reach the end of the month
        while(last_day_of_week <= last_day_of_cal)
          add_week_row 

          @top += row_heights[row_num]
          # increment the calendar row we are on, and the week
          @row_num += 1
          @first_day_of_week += 7
          @last_day_of_week += 7
        end
      end

      def add_week_row 
        week_row_container do
          week_background_table 

          calendar_row do
            day_numbers_row 

            options[:event_strips].each do |strip|
              event_row_for_this_day strip
            end
          end
        end
      end

      def week_row_container
        self << %(<div class="ec-row" style="top: #{top}px; height: #{row_heights[row_num]}px;">)
        yield
        self << %(</div>)
      end

      def week_background_table 
        self << %(<table class="ec-row-bg" cellpadding="0" cellspacing="0">)
        self << %(<tbody><tr>)
        first_day_of_week.upto(last_day_of_week) do |day|
          today_class = (day == Date.today) ? "ec-today-bg" : ""
          other_month_class = (day < first) || (day > last) ? 'ec-other-month-bg' : ''
          self << %(<td class="ec-day-bg #{today_class} #{other_month_class}">&nbsp;</td>)
        end
        self << %(</tr></tbody></table>)
      end

      def calendar_row
        self << %(<table class="ec-row-table" cellpadding="0" cellspacing="0">)
        self << %(<tbody>)
        yield
        self << %(</tbody></table>)
      end

      def day_numbers_row
        self << %(<tr>)
        first_day_of_week.upto(last_day_of_week) do |day|
          self << %(<td class="ec-day-header )

          self << %(ec-today-header )       if options[:show_today] and (day == Date.today)
          self << %(ec-other-month-header ) if (day < first) || (day > last)
          self << %(ec-weekend-day-header)  if weekend?(day)

          self << %(" style="height: #{options[:day_nums_height]}px;">)

          if options[:link_to_day_action]
            self << day_link(day.day, day, options[:link_to_day_action])
          else
            self << %(#{day.day})
          end
          self << %(</td>)
        end
        self << %(</tr>)
      end

      def event_row_for_this_day strip
        self << %(<tr>)
        # go through through the strip, for the entries that correspond to the days of this week
        strip[row_num*7, 7].each_with_index do |event, index|
          day = first_day_of_week + index

          if event
            new_cell_span event, day
          else
            empty_cell_and_container
          end
        end

        self << %(</tr>)
      end

      def new_cell_span event, day
        if starts_this_day? event, day
          no_bg event

          cell_container(event) do 
            add_arrows event

            if no_bg
              self << %(<div class="ec-bullet" style="background-color: #{event.color};"></div>)
              # make sure anchor text is the event color
              # here b/c CSS 'inherit' color doesn't work in all browsers
              self << %(<style type="text/css">.ec-#{css_for(event)}-#{event.id} a { color: #{event.color}; }</style>)
            end

            if @block
              # add the additional html that was passed as a block to this helper
              self << @block.call({:event => event, :day => day.to_date, :options => options})
            else
              default_cell_content event
            end
          end
        end

      end

      def empty_cell_and_container
        self << %(<td class="ec-event-cell ec-no-event-cell" )
        self << %(style="padding-top: #{options[:event_margin]}px;">)
        self << %(<div class="ec-event" )
        self << %(style="padding-top: #{options[:event_padding_top]}px; )
        self << %(height: #{options[:event_height] - options[:event_padding_top]}px;" )
        self << %(>)
        self << %(&nbsp;</div></td>)
      end

      def cell_attributes event
        if no_bg
          self << %(ec-event-no-bg" )
          self << %(style="color: #{event.color}; )
        else
          self << %(ec-event-bg" )
          self << %(style="background-color: #{event.color}; )
        end

        self << %(padding-top: #{options[:event_padding_top]}px; )
        self << %(height: #{options[:event_height] - options[:event_padding_top]}px;" )

        if options[:use_javascript]
          # custom attributes needed for javascript event highlighting
          self << %(data-event-id="#{event.id}" data-event-class="#{css_for(event)}" data-color="#{event.color}" )
        end
      end

      def cell_container event
        cspan = (last_day_in_week_for(event)-first_day_in_week_for(event)).to_i + 1

        self << %(<td class="ec-event-cell" colspan="#{cspan}" )
        self << %(style="padding-top: #{options[:event_margin]}px;">)
        self << %(<div class="ec-event ec-#{css_for(event)}-#{event.id} )
        cell_attributes event
        self << %(>)

        yield

        self << %(</div></td>)
      end

      def add_arrows event
        # add a left arrow if event is clipped at the beginning
        if event.start_at.to_date < first_day_in_week_for(event)
          self << %(<div class="ec-left-arrow"></div>)
        end

        # add a right arrow if event is clipped at the end
        if event.end_at.to_date > last_day_in_week_for(event)
          self << %(<div class="ec-right-arrow"></div>)
        end
      end

      def default_cell_content event
        self << %(<a href="/#{css_for(event).pluralize}/#{event.id}" title="#{(event.name)}">#{(event.name)}</a>)
      end

      #little helper methods to replace local variables in previous ubermethod

      # make the height calculations
      # tricky since multiple events in a day could 
      # force an increase in the set height
      def row_heights
        cal_row_heights(options)
      end

      def height
        height = options[:day_names_height]
        row_heights.each do |row_height|
          height += row_height
        end
        height
      end

      def day_names
        day_names = []
        if options[:abbrev]
          day_names.concat(I18n.translate(:'date.abbr_day_names'))
        else
          day_names.concat(I18n.translate(:'date.day_names'))
        end
        options[:first_day_of_week].times do
          day_names.push(day_names.shift)
        end
        day_names
      end
 
      def css_for event
        event.class.name.tableize.singularize
      end

      def starts_this_day? event, day
        first_day_in_week_for(event) == day.to_date
      end

      def no_bg event=nil
        if event
          @no_bg = no_event_bg?(event, options)
        else
          @no_bg
        end
      end

      def first_day_in_week_for event
        dates_within_this_week_for(event)[0]
      end

      def last_day_in_week_for event
        dates_within_this_week_for(event)[1]
      end

      def dates_within_this_week_for event
        event.clip_range(first_day_of_week, last_day_of_week)
      end

      def day_link(text, date, day_action)
        link_to(text, params.merge(:action => day_action, :year => date.year, :month => date.month, :day => date.day), :class => 'ec-day-link')
      end

      # check if we should display without a background color
      def no_event_bg?(event, options)
        options[:use_all_day] && !event.all_day && event.days == 0
      end

      # default html for displaying an event's time
      # to customize: override, or do something similar, in your helper
      # for instance, you may want to add localization
      def display_event_time(event, day)
        time = event.start_at
        if !event.all_day and time.to_date == day
          # try to make it display as short as possible
          format = (time.min == 0) ? "%l" : "%l:%M"
          t = time.strftime(format)
          am_pm = time.strftime("%p") == "PM" ? "p" : ""
          t += am_pm
        %(<span class="ec-event-time">#{t}</span>)
        else
        ""
        end
      end

      # calculate the height of each row
      # by default, it will be the height option minus the day names height,
      # divided by the total number of calendar rows
      # this gets tricky, however, if there are too many event rows to fit into the row's height
      # then we need to add additional height
      def cal_row_heights(options)
        # number of rows is the number of days in the event strips divided by 7
        num_cal_rows = options[:event_strips].first.size / 7
        # the row will be at least this big
        min_height = (options[:height] - options[:day_names_height]) / num_cal_rows
        row_heights = []
        num_event_rows = 0
        # for every day in the event strip...
        1.upto(options[:event_strips].first.size+1) do |index|
          num_events = 0
          # get the largest event strip that has an event on this day
          options[:event_strips].each_with_index do |strip, strip_num|
            num_events = strip_num + 1 unless strip[index-1].blank?
          end
          # get the most event rows for this week
          num_event_rows = [num_event_rows, num_events].max
          # if we reached the end of the week, calculate this row's height
          if index % 7 == 0
            total_event_height = options[:event_height] + options[:event_margin]

            calc_row_height = (num_event_rows * total_event_height) +
              options[:day_nums_height] + options[:event_margin]

            row_height = [min_height, calc_row_height].max
            row_heights << row_height
            num_event_rows = 0
          end
        end
        row_heights
      end

      # helper methods for working with a calendar week
      def days_between(first, second)
        if first > second
          second + (7 - first)
        else
          second - first
        end
      end

      def beginning_of_week(date, start = 0)
        days_to_beg = days_between(start, date.wday)
        date - days_to_beg
      end

      def end_of_week(date, start = 0)
        beg = beginning_of_week(date, start)
        beg + 6
      end

      def weekend?(date)
        [0, 6].include?(date.wday)
      end
    end
  end
end
