function [flows,selectedFlows] = f_distFlow(t,flows,Tslot,selFlow,aggregate)
% f_distFlow - It controls the PHY flows of the users, defined as the
% required bits to be transmitted per application per user. If more than
% one flow is present in the current time slot 't', then the flows are
% either aggregated or disaggregated. The aggregation is controlled by the
% flag 'aggregate'. The flows are updated and outputed accordingly. The
% function also returns the flow_ID for every user. If the ID is 0, no flow
% is selected (indices start in 1). This function is intended to be called
% at the very beginning of the iterative loop in the simulation.
%
% Syntax:  [flows,selectedFlows] = f_distFlow(t,flows,Tslot,aggregate,DEBUG)
%
% Inputs:
%    t - The current time slot.
%    flows - Information about the flow. For instance, the slots over which 
%            it is intended to transmit, the remaining amount of bits, the
%            expected throughput at a certain time slot, etcetera.
%    Tslot - Duration of the time slot.
%    selFlow - Last selected flow to boost the finding process.
%    aggregate - Boolean Flag (True or False) that controls the flow
%                aggregation policy.
%
% Outputs:
%    flows - Flows are updated accordingly in case there is an overlap in
%            time.
%    selectedFlows - Contains the flow IDs for each user. If a user do not 
%                    have a flow available at instant 't', the value is 0.
%                    The ID is used to map the requirements from variable
%                    'flow' further in the system.
%
% Example: 
%       problem = o_read_input_problem('data/metaproblem_test.dat');
%       conf = o_read_config('data/config_test.dat');
%       [problem,~,flows] = f_configuration(conf, problem);  % Struct with configuration parameters
%       [flows,selFlow] = f_distFlow(1,flows,32,true,true);
%
% Other m-files required: f_configuration
% Subfunctions: none
% MAT-files required: data/metaproblem_test.dat,  data/config_test.dat
%
% See also: f_configure,  f_genDetTraffic, main
% 
%------------- BEGIN CODE --------------

Nusers = length(flows);  % Total number of users
selectedFlows = zeros(Nusers,1);

for id = 1:Nusers
    numPkt = length(flows(id).slots);  % Maximum number of packets to iterate over
    % Last selected packet for reference. If not, set the minimum: 1
    pktRef = max(1,selFlow(id));
    % Determine the earliest unserved packet whose slots contain current t
    for pkt = (pktRef:1:numPkt)
        idx0 = find(ismember(flows(id).slots{pkt},t)~=0,1);
        if idx0
            % Reference packet that lays within current slot
            pktRef = pkt;
            % Select this packet for transmission
            selectedFlows(id) = pktRef;
            break;
        end
    end
    % Determine if any other packet overlaps in time with the current in t
    for pkt = (pktRef+1:1:numPkt)
        % Initialize control variables
        idx2 = false;
        % Only evaluate flow aggregation if we are not the last flow to
        % avoid array indexation out of available range (pkt+1)
        if pkt<=numPkt
            % idx1 controls overlapping between flows
            idx1 = find(ismember(flows(id).slots{pktRef},flows(id).slots{pkt})~=0,1);
            % idx2 controls if the overlapping happens within current slot
            idx2 = isequal(flows(id).slots{pktRef}(idx1),t);
        end
        if idx2 && aggregate
            % We DO aggregate traffic. This option increases the efficiency of the
            % traffic distribution. We follow a uniform traffic distribution
            % policy across the deadlines. Traffic is evenly distributed
            % between two periods:
            % Delta = 2nd deadline - current
            Delta = flows(id).deadlines(pkt) - t + 1;
            % Delta1 = 1nd deadline - current
            Delta1 = flows(id).deadlines(pktRef) - t + 1;
            % Delta2 = 2nd deadline - 1nd deadline
            Delta2 = flows(id).deadlines(pkt) - flows(id).deadlines(pktRef);
            % Define proportional variables
            X = flows(id).remaining(pktRef);
            Y = flows(id).remaining(pkt);
            alpha = Delta1/Delta;
            beta = Delta2/Delta;
            % Redefine remaining bits to be transmitted in each flow
            flows(id).remaining(pktRef)   = alpha * (X+Y);
            flows(id).remaining(pkt) =  beta * (X+Y);
            % Redefine the TH
            flows(id).TH(pktRef) = flows(id).remaining(pktRef) / (Delta1*Tslot*1e-3);
            flows(id).TH(pkt) = flows(id).remaining(pkt) / (Delta2*Tslot*1e-3);
            % Cut the number of slots for the second overlapping flow
            flows(id).slots{pkt} = (max(flows(id).slots{pktRef}) + 1 ...
                                      : 1 : max(flows(id).slots{pkt}));
        elseif idx2 && ~aggregate
            % (TODO)
            % We DO NOT aggregate traffic, meaning that we disaggregate any
            % overlapping flow in time (slot). In other words, we wait until we
            % finish the transmission of one flow before start transmitting the
            % next one. While we decrease the load on the antenna selection
            % side (less throughput) on the first interval (1nd deadline -
            % current), we increase substantially the demanded throughput in
            % the second one (2nd deadline - 1nd deadline).
        end
    end

end


% EOF
