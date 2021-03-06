classdef EKF3DConstMomentum < handle
    properties
        delta_t
        K
        Q
        R
        f
        Phi
        h
        H
    end

    methods
        function obj = EKF3DConstMomentum(delta_t, inertia, Q, R)
            % State vector: [q1 q2, q3, q4, omega1, omega2, omega3]
            % measurement z = [E1_1, E1_2, E1_3, E2_1, E2_2, E2_3]
            EKF3DConstMomentumSymbolicDerivation
            f__ = matlabFunction(subs(f, [dt; I11; I22; I33], [delta_t; inertia']), 'Vars', x);
            obj.f = @(x_, u) f__(x_(1), x_(2), x_(3), x_(4), x_(5), x_(6), x_(7));
            % f_ = @(x_, u) state_update(x_, delta_t); % use ode45, INERTIA IS HARDCODED!!!
            F__ = matlabFunction(subs(F, [dt; I11; I22; I33], [delta_t; inertia']), 'Vars', x);
            obj.Phi = @(x_, u) F__(x_(1), x_(2), x_(3), x_(4), x_(5), x_(6), x_(7));
            h__ = matlabFunction(subs(h, dt, delta_t), 'Vars', x);
            obj.h = @(x_) h__(x_(1), x_(2), x_(3), x_(4), x_(5), x_(6), x_(7));
            H__ = matlabFunction(subs(H, dt, delta_t), 'Vars', x);
            obj.H = @(x_) H__(x_(1), x_(2), x_(3), x_(4), x_(5), x_(6), x_(7));
            obj.Q = Q;
            obj.R = R;
            obj.K = ExtendedKalmanFilter(7);
            obj.delta_t = delta_t;
        end

        function renormalize_quaternion(self)
            n = norm(self.K.x(1:4));
            self.K.x(1:4) = self.K.x(1:4)/n;
        end

        function predict(self, unused_gyro)
            self.K.predict(self.f, self.Phi(self.K.x), self.Q)
            self.renormalize_quaternion()
        end

        function measure(self, E1, E2)
            self.K.measure([E1; E2], self.R, self.h, self.H(self.K.x))
            self.renormalize_quaternion()
        end

        function att = get_attitude(self)
            att = self.K.x(1:4);
        end

        function omega = get_omega(self)
            omega = self.K.x(5:7);
        end
    end
end


function x = state_update(x, delta_t)
    [t, x]=ode45(@diff_eq, [0 delta_t], x);
    x = x(end, :)'
end

function x_dot = diff_eq(t, x)
    attitude = x(1:4)
    omega = x(5:7)
    attitude_dot = 1/2 * quatmult(attitude, [0; omega]);
    I = diag([1, 2, 3]);
    % T = I * omega_dot + omega x I * omega
    omega_dot = I \ ([0; 0; 0] - cross(omega, I * omega));
    x_dot = [attitude_dot; omega_dot]
end