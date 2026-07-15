"use client";

import { useCurrentUser } from "@/app/(dashboard)/hooks/users/useCurrentUser";
import useAuthorized from "@/app/(dashboard)/hooks/useAuthorized";
import MessageManager from "@/components/molecules/message_manager";
import { changePasswordCall } from "@/components/networking";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { Alert, Button, Card, Form, Input, Typography } from "antd";
import { useMemo } from "react";

function formatPasswordExpiry(passwordExpiry: string | null | undefined): string | null {
  if (!passwordExpiry) {
    return null;
  }

  const parsed = new Date(passwordExpiry);
  if (Number.isNaN(parsed.getTime())) {
    return passwordExpiry;
  }

  return parsed.toLocaleString();
}

export default function ChangePasswordPage() {
  const { accessToken } = useAuthorized();
  const queryClient = useQueryClient();
  const { data: currentUser } = useCurrentUser();
  const [form] = Form.useForm();

  const passwordExpiryLabel = useMemo(
    () => formatPasswordExpiry(currentUser?.password_expiry),
    [currentUser?.password_expiry],
  );

  const mutation = useMutation({
    mutationFn: async (values: { currentPassword: string; newPassword: string }) => {
      if (!accessToken) {
        throw new Error("Access token is required");
      }

      return changePasswordCall(accessToken, values.currentPassword, values.newPassword);
    },
    onSuccess: async (response) => {
      MessageManager.success(response.message);
      form.resetFields();
      await queryClient.invalidateQueries({ queryKey: ["users"] });
    },
    onError: (error) => {
      MessageManager.error(error instanceof Error ? error.message : "Failed to change password");
    },
  });

  return (
    <div className="mx-auto w-full max-w-2xl p-8">
      <Card>
        <Typography.Title level={3}>Change password</Typography.Title>
        <Typography.Paragraph>
          Update your Console password. You must confirm your current password before setting a new one.
        </Typography.Paragraph>

        {passwordExpiryLabel ? (
          <Alert
            className="mb-6"
            type="info"
            showIcon
            message={`Current password expires on ${passwordExpiryLabel}`}
          />
        ) : null}

        <Form
          form={form}
          layout="vertical"
          onFinish={(values: { currentPassword: string; newPassword: string; confirmNewPassword: string }) => {
            mutation.mutate({
              currentPassword: values.currentPassword,
              newPassword: values.newPassword,
            });
          }}
        >
          <Form.Item
            label="Current password"
            name="currentPassword"
            rules={[{ required: true, message: "Current password is required" }]}
          >
            <Input.Password autoComplete="current-password" />
          </Form.Item>

          <Form.Item
            label="New password"
            name="newPassword"
            rules={[{ required: true, message: "New password is required" }]}
          >
            <Input.Password autoComplete="new-password" />
          </Form.Item>

          <Form.Item
            label="Confirm new password"
            name="confirmNewPassword"
            dependencies={["newPassword"]}
            rules={[
              { required: true, message: "Please confirm your new password" },
              ({ getFieldValue }) => ({
                validator(_, value) {
                  if (!value || getFieldValue("newPassword") === value) {
                    return Promise.resolve();
                  }
                  return Promise.reject(new Error("New passwords do not match"));
                },
              }),
            ]}
          >
            <Input.Password autoComplete="new-password" />
          </Form.Item>

          <Button type="primary" htmlType="submit" loading={mutation.isPending}>
            Change password
          </Button>
        </Form>
      </Card>
    </div>
  );
}
