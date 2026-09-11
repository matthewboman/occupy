module MarketData
  class TradingCalendar
    class << self
      def open?(date)
        date = date.to_date

        weekday?(date) &&
          !holiday?(date)
      end

      private

      def weekday?(date)
        !date.saturday? && !date.sunday?
      end

      def holiday?(date)
        holidays(date.year).include?(date)
      end

      def holidays(year)
        [
          observed(Date.new(year, 1, 1)),
          nth_weekday(year, 1, 1, 3),
          nth_weekday(year, 2, 1, 3),
          good_friday(year),
          last_weekday(year, 5, 1),
          observed(Date.new(year, 6, 19)),
          observed(Date.new(year, 7, 4)),
          nth_weekday(year, 9, 1, 1),
          nth_weekday(year, 11, 4, 4),
          observed(Date.new(year, 12, 25))
        ]
      end

      def observed(date)
        case date.wday
        when 0
          date + 1.day
        when 6
          date - 1.day
        else
          date
        end
      end

      def nth_weekday(year, month, weekday, occurrence)
        date = Date.new(year, month, 1)

        date += 1.day until date.wday == weekday

        date + ((occurrence - 1) * 7).days
      end

      def last_weekday(year, month, weekday)
        date = Date.new(year, month, -1)

        date -= 1.day until date.wday == weekday

        date
      end

      def good_friday(year)
        easter_date(year) - 2.days
      end

      def easter_date(year)
        a = year % 19
        b = year / 100
        c = year % 100
        d = b / 4
        e = b % 4
        f = (b + 8) / 25
        g = (b - f + 1) / 3
        h = (19 * a + b - d - g + 15) % 30
        i = c / 4
        k = c % 4
        l = (32 + 2 * e + 2 * i - h - k) % 7
        m = (a + 11 * h + 22 * l) / 451

        month = (h + l - 7 * m + 114) / 31
        day = ((h + l - 7 * m + 114) % 31) + 1

        Date.new(year, month, day)
      end
    end
  end
end