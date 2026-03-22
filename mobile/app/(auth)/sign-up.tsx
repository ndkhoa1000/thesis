import { useState } from 'react';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  KeyboardAvoidingView,
  Platform,
  Alert,
  ActivityIndicator,
} from 'react-native';
import { Link } from 'expo-router';
import { useAuth } from '@/contexts/AuthContext';

export default function SignUpScreen() {
  const { signUp } = useAuth();
  const [email, setEmail] = useState('');
  const [fullName, setFullName] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSignUp = async () => {
    if (!email || !password || !fullName) {
      Alert.alert('Lỗi', 'Vui lòng nhập họ tên, email và mật khẩu');
      return;
    }

    if (password !== confirmPassword) {
      Alert.alert('Lỗi', 'Mật khẩu xác nhận không khớp');
      return;
    }

    if (password.length < 6) {
      Alert.alert('Lỗi', 'Mật khẩu phải có ít nhất 6 ký tự');
      return;
    }

    setLoading(true);
    const { error } = await signUp(email, password, fullName);
    setLoading(false);

    if (error) {
      Alert.alert('Đăng ký thất bại', error.message);
    } else {
      Alert.alert('Thành công', 'Vui lòng kiểm tra email để xác nhận tài khoản');
    }
  };

  return (
    <KeyboardAvoidingView
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      className="flex-1 bg-white dark:bg-slate-900"
    >
      <View className="flex-1 justify-center px-8">
        {/* Header */}
        <View className="items-center mb-10">
          <Text className="text-4xl font-bold text-primary-500 mb-2">🅿️ ParkSmart</Text>
          <Text className="text-base text-slate-500 dark:text-slate-400">
            Tạo tài khoản mới
          </Text>
        </View>

        {/* Form */}
        <View className="gap-4">
          <View>
            <Text className="text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
              Họ tên
            </Text>
            <TextInput
              className="h-12 px-4 rounded-xl bg-slate-100 dark:bg-slate-800 text-base text-slate-900 dark:text-white"
              placeholder="Nguyễn Văn A"
              placeholderTextColor="#94a3b8"
              value={fullName}
              onChangeText={setFullName}
            />
          </View>

          <View>
            <Text className="text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
              Email
            </Text>
            <TextInput
              className="h-12 px-4 rounded-xl bg-slate-100 dark:bg-slate-800 text-base text-slate-900 dark:text-white"
              placeholder="you@example.com"
              placeholderTextColor="#94a3b8"
              value={email}
              onChangeText={setEmail}
              autoCapitalize="none"
              keyboardType="email-address"
            />
          </View>

          <View>
            <Text className="text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
              Mật khẩu
            </Text>
            <TextInput
              className="h-12 px-4 rounded-xl bg-slate-100 dark:bg-slate-800 text-base text-slate-900 dark:text-white"
              placeholder="Tối thiểu 6 ký tự"
              placeholderTextColor="#94a3b8"
              value={password}
              onChangeText={setPassword}
              secureTextEntry
            />
          </View>

          <View>
            <Text className="text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
              Xác nhận mật khẩu
            </Text>
            <TextInput
              className="h-12 px-4 rounded-xl bg-slate-100 dark:bg-slate-800 text-base text-slate-900 dark:text-white"
              placeholder="Nhập lại mật khẩu"
              placeholderTextColor="#94a3b8"
              value={confirmPassword}
              onChangeText={setConfirmPassword}
              secureTextEntry
            />
          </View>

          <TouchableOpacity
            className="h-12 rounded-xl bg-primary-500 items-center justify-center mt-2"
            onPress={handleSignUp}
            disabled={loading}
            activeOpacity={0.8}
          >
            {loading ? (
              <ActivityIndicator color="white" />
            ) : (
              <Text className="text-white text-base font-semibold">Đăng ký</Text>
            )}
          </TouchableOpacity>
        </View>

        {/* Footer */}
        <View className="flex-row justify-center mt-6">
          <Text className="text-slate-500 dark:text-slate-400">Đã có tài khoản? </Text>
          <Link href="/(auth)/sign-in" asChild>
            <TouchableOpacity>
              <Text className="text-primary-500 font-semibold">Đăng nhập</Text>
            </TouchableOpacity>
          </Link>
        </View>
      </View>
    </KeyboardAvoidingView>
  );
}
