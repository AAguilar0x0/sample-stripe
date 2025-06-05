export class AuthRepo {
  async getCurrentUser() {
    return {
      id: '123',
      name: 'John Doe',
      email: 'john.doe@example.com',
    }
  }
}
