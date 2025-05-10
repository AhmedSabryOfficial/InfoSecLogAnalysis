#!/bin/bash

LOG_SOURCE="access.log"
OUTPUT_REPORT="server_analysis.txt"

# Validate log file existence
if [ ! -f "$LOG_SOURCE" ]; then
    echo "Error: Access log file $LOG_SOURCE not found!"
    exit 1
fi

# Initialize analysis report
echo "==== Web Server Traffic Analysis =====" > "$OUTPUT_REPORT"
echo "Generated: $(date)" >> "$OUTPUT_REPORT"
echo "======================================" >> "$OUTPUT_REPORT"

# Process log data with corrected time parsing
awk '
    BEGIN {
        # Initialize month abbreviations to numbers
        months["Jan"] = 1; months["Feb"] = 2; months["Mar"] = 3;
        months["Apr"] = 4; months["May"] = 5; months["Jun"] = 6;
        months["Jul"] = 7; months["Aug"] = 8; months["Sep"] = 9;
        months["Oct"] = 10; months["Nov"] = 11; months["Dec"] = 12;
    }
    {
        # Core metrics
        total_requests++
        if ($6 == "\"GET") get_count++
        if ($6 == "\"POST") post_count++
        
        # IP analysis
        ip_list[$1]++
        
        # Status code tracking
        status_code = $9
        status_codes[status_code]++
        
        # Error tracking (valid status codes only)
        if ($9 ~ /^[45][0-9]{2}$/) {
            error_total++
            error_codes[$9]++
        }
        
        # Improved time parsing
        split($4, dt_parts, /[[\/:]/)
        day = dt_parts[2]
        month_abbr = dt_parts[3]
        year = dt_parts[4]
        hour_str = dt_parts[5]
        
        # Convert to epoch timestamp
        month_num = months[month_abbr]
        epoch = mktime(year " " month_num " " day " 00 00 00")
        
        # Track date range
        if (epoch < min_epoch || min_epoch == "") min_epoch = epoch
        if (epoch > max_epoch || max_epoch == "") max_epoch = epoch
        
        # Date and hour counts
        date_str = day "/" month_abbr "/" year
        date_counts[date_str]++
        hour_counts[hour_str]++
    }
    END {
        # Basic statistics
        printf "Total Requests: %d\n", total_requests
        printf "GET Requests: %d (%.2f%%)\n", get_count, (get_count/total_requests)*100
        printf "POST Requests: %d (%.2f%%)\n\n", post_count, (post_count/total_requests)*100
        
        # Unique IP analysis
        printf "Unique IP Addresses: %d\n", length(ip_list)
        print "\nTop 10 Active IPs:"
        system("")
        for (ip in ip_list) {
            print ip_list[ip], ip | "sort -nr | head -10"
        }
        close("sort -nr | head -10")
        
        # Error analysis
        printf "\nFailed Requests: %d (%.2f%%)\n", error_total, (error_total/total_requests)*100
        print "Most Common Error Codes:"
        system("")
        for (code in error_codes) {
            print error_codes[code], code | "sort -nr | head -5"
        }
        close("sort -nr | head -5")
        
        # Status Code Breakdown
        print "\nStatus Code Breakdown:"
        printf "%-6s %-10s %s\n", "Code", "Count", "Percentage"
        for (code in status_codes) {
            printf "%-6s %-10d %.2f%%\n", code, status_codes[code], (status_codes[code]/total_requests)*100
        }
        
        # Daily Request Averages
        if (min_epoch != "" && max_epoch != "") {
            total_days = (max_epoch - min_epoch) / 86400 + 1
            daily_avg = total_requests / total_days
            printf "\nDaily Request Average: %.2f requests/day (over %d days)\n", daily_avg, total_days
        }
        
        # High-error days
        print "\nTop 5 High-Error Days:"
        system("")
        for (day in date_counts) {
            print date_counts[day], day | "sort -nr | head -5"
        }
        close("sort -nr | head -5")
        
        # Hourly distribution
        print "\nHourly Traffic Distribution:"
        for (h=0; h<24; h++) {
            hour_fmt = sprintf("%02d", h)
            count = hour_counts[hour_fmt] + 0  # Force numeric conversion
            printf "%s:00 - %d requests\n", hour_fmt, count
        }
    }
' "$LOG_SOURCE" >> "$OUTPUT_REPORT"

# Add improvement recommendations
echo "
==== Optimization Recommendations ====
1. Reduce error rates by:
   - Fixing broken links (404 errors)
   - Reviewing server logs for 500 errors
2. Enhance performance:
   - Scale resources during peak hours
   - Implement caching mechanisms
3. Security improvements:
   - Monitor unusual IP activity
   - Implement request rate limiting" >> "$OUTPUT_REPORT"

echo "Analysis report generated: $OUTPUT_REPORT"