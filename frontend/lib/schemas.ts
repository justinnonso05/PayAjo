import { z } from "zod";

export const registerSchema = z.object({
  firstName: z.string().trim().min(1, "First name is required"),
  lastName: z.string().trim().min(1, "Last name is required"),
  username: z
    .string()
    .trim()
    .min(3, "Username must be at least 3 characters")
    .regex(/^[a-zA-Z0-9_]+$/, "Only letters, numbers, and underscores"),
  email: z.string().trim().email("Enter a valid email address"),
  phone: z
    .string()
    .trim()
    .regex(/^\+?[0-9]{10,14}$/, "Enter a valid phone number"),
  password: z.string().min(8, "Password must be at least 8 characters"),
});

export type RegisterFormValues = z.infer<typeof registerSchema>;

export const loginSchema = z.object({
  email: z.string().trim().email("Enter a valid email address"),
  password: z.string().min(1, "Password is required"),
});

export type LoginFormValues = z.infer<typeof loginSchema>;

export const forgotPasswordSchema = z.object({
  email: z.string().trim().email("Enter a valid email address"),
});

export type ForgotPasswordFormValues = z.infer<typeof forgotPasswordSchema>;

export const resetPasswordSchema = z
  .object({
    otpCode: z.string().trim().min(4, "Enter the code from your email"),
    newPassword: z.string().min(8, "Password must be at least 8 characters"),
    confirmPassword: z.string(),
  })
  .refine((data) => data.newPassword === data.confirmPassword, {
    message: "Passwords don't match",
    path: ["confirmPassword"],
  });

export type ResetPasswordFormValues = z.infer<typeof resetPasswordSchema>;

export const bvnSchema = z.object({
  bvn: z
    .string()
    .trim()
    .regex(/^[0-9]{11}$/, "BVN must be exactly 11 digits"),
});

export type BvnFormValues = z.infer<typeof bvnSchema>;

export const createGroupSchema = z.object({
  name: z.string().trim().min(2, "Group name is required"),
  contributionAmount: z.coerce.number().positive("Enter an amount greater than 0"),
  cycleFrequency: z.enum(["weekly", "monthly", "yearly"]),
  // These are all optional and parsed manually on submit (not coerced by
  // zod) since an empty optional number input coerces to NaN, which would
  // fail min/max checks even though nothing was entered.
  payoutDayOfWeek: z.number().min(0).max(6).optional(),
  payoutDayOfMonth: z.string().optional(),
  payoutMonth: z.string().optional(),
  payoutTime: z.string().optional(),
  memberCap: z.string().optional(),
});

export type CreateGroupFormValues = z.infer<typeof createGroupSchema>;

export const joinGroupSchema = z.object({
  inviteCode: z.string().trim().min(4, "Enter a valid invite code"),
});

export type JoinGroupFormValues = z.infer<typeof joinGroupSchema>;
