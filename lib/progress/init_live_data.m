function live_data = init_live_data(fname)
%init_live_data creates a live_data database structure

live_data.filename = fname;
live_data.done = false;
live_data.cal.current_idx   = [];
live_data.vid.current_idx   = [];
live_data.mon.current_idx   = [];
live_data.eye               = [];
live_data.date              = [];
live_data.id                = [];

end

