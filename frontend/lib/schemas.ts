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
});

export type CreateGroupFormValues = z.infer<typeof createGroupSchema>;

export const joinGroupSchema = z.object({
  inviteCode: z.string().trim().min(4, "Enter a valid invite code"),
});

export type JoinGroupFormValues = z.infer<typeof joinGroupSchema>;
