% lsl debug script

clear all
lsl = LSL(2,0,1:32,0);

b = lsl_local_clock(lsl.lib)

flushBuffer(lsl)

% open stream
lsl.Marker_inlet.open_stream()

% send a marker
for i=1:10
sendMarker(lsl,int2str(i));
% recieve a marker
a=[];
while(isempty(a))
 [a,ts] = lsl.Marker_inlet.pull_sample(0);
end
display(a);
pause(0.5);
end

for i=1:10
[a,ts] = lsl.Marker_inlet.pull_sample(0);
display(a)
pause(0.5);
end


display(ts);


sendMarker(lsl,'SSVEP-start_trial1');
sendMarker(lsl,'SSVEP-start_trial2');
sendMarker(lsl,'SSVEP-start_trial3');
sendMarker(lsl,'SSVEP-start_trial4');


[data, ts] = lsl.Marker_inlet.pull_chunk();

[data, ts] = lsl.EEG_inlet.pull_chunk();

 a=lsl_local_clock(1)